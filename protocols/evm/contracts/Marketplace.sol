// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { RegistryRouter } from "./RegistryRouter.sol";
import { ProtocolLib, TokenLib } from "./Libraries.sol";
import { RoboshareTokens } from "./RoboshareTokens.sol";
import { PartnerManager } from "./PartnerManager.sol";
import { Treasury } from "./Treasury.sol";

// Marketplace errors
error Marketplace__ZeroAddress();
error Marketplace__ListingNotFound();
error Marketplace__NotTokenOwner();
error Marketplace__ListingExpired();
error Marketplace__InsufficientPayment();
error Marketplace__InvalidTokenType();
error Marketplace__InvalidAmount();
error Marketplace__ListingNotActive();
error Marketplace__NoCollateralLocked();
error Marketplace__InsufficientTokenBalance();
error Marketplace__FeesExceedPrice();
error Marketplace__InvalidPrice();

/**
 * @dev Marketplace for buying and selling revenue share tokens
 * Handles listing creation, purchasing, and fee distribution
 * Integrates with Treasury to ensure collateral is locked before listing
 */
contract Marketplace is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Core contracts
    RoboshareTokens public roboshareTokens;
    PartnerManager public partnerManager;
    RegistryRouter public router;
    Treasury public treasury;
    IERC20 public usdcToken;

    // Treasury state
    address public treasuryFeeRecipient;

    // Listing management
    uint256 private _listingIdCounter;

    struct Listing {
        uint256 listingId;
        uint256 tokenId;
        uint256 amount;
        uint256 pricePerToken; // Price in USDC (6 decimals)
        address seller;
        uint256 expiresAt;
        bool isActive;
        uint256 createdAt;
        bool buyerPaysFee; // If true, buyer pays protocol fee; if false, seller absorbs fee
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => uint256[]) public assetListings; // assetId => listingIds[]

    // Events
    event ListingCreated(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        uint256 indexed assetId,
        address seller,
        uint256 amount,
        uint256 pricePerToken,
        uint256 expiresAt,
        bool buyerPaysFee
    );

    event RevenueTokensTraded(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 listingId,
        uint256 totalPrice
    );

    event ListingCancelled(uint256 indexed listingId, address indexed seller);

    event TreasuryAddressUpdated(address oldTreasury, address newTreasury);

    /**
     * @dev Initialize the marketplace
     */
    function initialize(
        address _admin,
        address _roboshareTokens,
        address _partnerManager,
        address _router,
        address _treasury,
        address _usdcToken,
        address _treasuryFeeRecipient
    ) public initializer {
        if (
            _admin == address(0) || _roboshareTokens == address(0) || _partnerManager == address(0)
                || _router == address(0) || _treasury == address(0) || _usdcToken == address(0)
                || _treasuryFeeRecipient == address(0)
        ) {
            revert Marketplace__ZeroAddress();
        }

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);

        roboshareTokens = RoboshareTokens(_roboshareTokens);
        partnerManager = PartnerManager(_partnerManager);
        router = RegistryRouter(_router);
        treasury = Treasury(_treasury);
        usdcToken = IERC20(_usdcToken);
        treasuryFeeRecipient = _treasuryFeeRecipient;

        _listingIdCounter = 1;
    }

    /**
     * @dev Modifier to ensure only authorized partners can call functions
     */
    modifier onlyAuthorizedPartner() {
        if (!partnerManager.isAuthorizedPartner(msg.sender)) {
            revert PartnerManager.PartnerManager__NotAuthorized();
        }
        _;
    }

    /**
     * @dev Create a listing for revenue share tokens (requires collateral to be locked)
     * @param tokenId The revenue share token ID
     * @param amount Number of tokens to list
     * @param pricePerToken Price per token in USDC
     * @param duration Listing duration in seconds
     * @param buyerPaysFee If true, buyer pays protocol fee; if false, seller absorbs fee
     */
    function createListing(uint256 tokenId, uint256 amount, uint256 pricePerToken, uint256 duration, bool buyerPaysFee)
        external
        nonReentrant
        returns (uint256 listingId)
    {
        // Validate token type (must be revenue share token)
        if (!TokenLib.isRevenueToken(tokenId)) {
            revert Marketplace__InvalidTokenType();
        }
        if (pricePerToken == 0) {
            revert Marketplace__InvalidPrice();
        }

        uint256 tokenSupply = roboshareTokens.getRevenueTokenSupply(tokenId);

        // Validate inputs
        if (amount == 0 || amount > tokenSupply) {
            revert Marketplace__InvalidAmount();
        }

        // Verify seller owns enough tokens
        uint256 sellerBalance = roboshareTokens.balanceOf(msg.sender, tokenId);
        if (sellerBalance < amount) {
            revert Marketplace__InsufficientTokenBalance();
        }

        // Get asset ID and check collateral is locked
        uint256 assetId = router.getAssetIdFromTokenId(tokenId);

        // Check asset status is Active
        if (router.getAssetStatus(assetId) != AssetLib.AssetStatus.Active) {
            revert Marketplace__ListingNotActive();
        }

        (,, bool isLocked,,) = treasury.getAssetCollateralInfo(assetId);
        if (!isLocked) {
            revert Marketplace__NoCollateralLocked();
        }

        return _createListing(tokenId, amount, pricePerToken, duration, buyerPaysFee);
    }

    /**
     * @dev Internal function to create listing
     */
    function _createListing(uint256 tokenId, uint256 amount, uint256 pricePerToken, uint256 duration, bool buyerPaysFee)
        internal
        returns (uint256 listingId)
    {
        // Get asset ID for indexing
        uint256 assetId = router.getAssetIdFromTokenId(tokenId);

        // Create listing
        listingId = _listingIdCounter++;
        uint256 expiresAt = block.timestamp + duration;

        listings[listingId] = Listing({
            listingId: listingId,
            tokenId: tokenId,
            amount: amount,
            pricePerToken: pricePerToken,
            seller: msg.sender,
            expiresAt: expiresAt,
            isActive: true,
            createdAt: block.timestamp,
            buyerPaysFee: buyerPaysFee
        });

        // Add to asset listings index
        assetListings[assetId].push(listingId);

        // Transfer tokens to marketplace for escrow
        roboshareTokens.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");

        emit ListingCreated(listingId, tokenId, assetId, msg.sender, amount, pricePerToken, expiresAt, buyerPaysFee);

        return listingId;
    }

    /**
     * @dev Purchase tokens from a listing
     */
    function purchaseTokens(uint256 listingId, uint256 amount) external nonReentrant {
        Listing storage listing = listings[listingId];

        // Validate listing exists and is active
        if (listing.listingId == 0) {
            revert Marketplace__ListingNotFound();
        }

        // Check asset status
        uint256 assetId = router.getAssetIdFromTokenId(listing.tokenId);
        if (router.getAssetStatus(assetId) != AssetLib.AssetStatus.Active) {
            revert Marketplace__ListingNotActive();
        }

        if (!listing.isActive) {
            revert Marketplace__ListingNotActive();
        }
        if (block.timestamp > listing.expiresAt) {
            revert Marketplace__ListingExpired();
        }
        if (amount == 0 || amount > listing.amount) {
            revert Marketplace__InvalidAmount();
        }

        // Calculate base payment amounts
        uint256 totalPrice = amount * listing.pricePerToken;
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(totalPrice);
        uint256 salesPenalty = roboshareTokens.getSalesPenalty(listing.seller, listing.tokenId, amount);

        uint256 expectedPayment;
        uint256 sellerReceives;
        uint256 totalFeesToTreasury = protocolFee + salesPenalty;

        if (listing.buyerPaysFee) {
            // Buyer pays the listed price + the protocol fee.
            if (salesPenalty > totalPrice) {
                revert Marketplace__FeesExceedPrice();
            }
            expectedPayment = totalPrice + protocolFee;
            // Seller receives the listed price, but the sales penalty is deducted from their share.
            sellerReceives = totalPrice - salesPenalty;
        } else {
            // Buyer pays only the listed price.
            if (totalFeesToTreasury > totalPrice) {
                revert Marketplace__FeesExceedPrice();
            }
            expectedPayment = totalPrice;
            // Seller receives the listed price, but both protocol fee and sales penalty are deducted.
            sellerReceives = totalPrice - totalFeesToTreasury;
        }

        // Check buyer has sufficient USDC
        if (usdcToken.balanceOf(msg.sender) < expectedPayment) {
            revert Marketplace__InsufficientPayment();
        }

        // Update listing
        listing.amount -= amount;
        if (listing.amount == 0) {
            listing.isActive = false;
        }

        // Transfer USDC payments
        usdcToken.transferFrom(msg.sender, listing.seller, sellerReceives);
        // Transfer fees to the Treasury contract and notify it to record the pending withdrawal
        usdcToken.transferFrom(msg.sender, address(treasury), totalFeesToTreasury);
        treasury.recordPendingWithdrawal(treasuryFeeRecipient, totalFeesToTreasury);

        // Transfer tokens to buyer
        roboshareTokens.safeTransferFrom(address(this), msg.sender, listing.tokenId, amount, "");

        emit RevenueTokensTraded(listing.tokenId, listing.seller, msg.sender, amount, listingId, totalPrice);
    }

    /**
     * @dev Cancel a listing and return tokens to seller
     */
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];

        // Validate listing exists and caller is seller
        if (listing.listingId == 0) {
            revert Marketplace__ListingNotFound();
        }
        if (listing.seller != msg.sender) {
            revert Marketplace__NotTokenOwner();
        }
        if (!listing.isActive) {
            revert Marketplace__ListingNotActive();
        }

        // Mark as inactive
        listing.isActive = false;

        // Return tokens to seller
        roboshareTokens.safeTransferFrom(address(this), listing.seller, listing.tokenId, listing.amount, "");

        emit ListingCancelled(listingId, msg.sender);
    }

    // View Functions

    /**
     * @dev Get listing details
     */
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    /**
     * @dev Get active listings for a asset
     */
    function getAssetListings(uint256 assetId) external view returns (uint256[] memory activeListings) {
        uint256[] memory allListings = assetListings[assetId];
        uint256 activeCount = 0;

        // Count active listings
        for (uint256 i = 0; i < allListings.length; i++) {
            Listing storage listing = listings[allListings[i]];
            if (listing.isActive && block.timestamp <= listing.expiresAt) {
                activeCount++;
            }
        }

        // Build active listings array
        activeListings = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allListings.length; i++) {
            Listing storage listing = listings[allListings[i]];
            if (listing.isActive && block.timestamp <= listing.expiresAt) {
                activeListings[index] = allListings[i];
                index++;
            }
        }

        return activeListings;
    }

    /**
     * @dev Calculate purchase cost including fees
     */
    function calculatePurchaseCost(uint256 listingId, uint256 amount)
        external
        view
        returns (uint256 totalCost, uint256 protocolFee, uint256 expectedPayment)
    {
        Listing storage listing = listings[listingId];

        totalCost = amount * listing.pricePerToken;
        protocolFee = ProtocolLib.calculateProtocolFee(totalCost);
        expectedPayment = listing.buyerPaysFee ? totalCost + protocolFee : totalCost;

        return (totalCost, protocolFee, expectedPayment);
    }

    /**
     * @dev Get current listing counter
     */
    function getCurrentListingId() external view returns (uint256) {
        return _listingIdCounter;
    }

    /**
     * @dev Check if asset has locked collateral (required for listing)
     */
    function isAssetEligibleForListing(uint256 assetId) external view returns (bool) {
        (,, bool isLocked,,) = treasury.getAssetCollateralInfo(assetId);
        return isLocked;
    }

    // Admin Functions

    /**
     * @dev Update treasury address for protocol fees
     */
    function setTreasuryFeeRecipient(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) {
            revert Marketplace__ZeroAddress();
        }

        address oldTreasury = treasuryFeeRecipient;
        treasuryFeeRecipient = newTreasury;

        emit TreasuryAddressUpdated(oldTreasury, newTreasury);
    }

    // UUPS Upgrade authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    /**
     * @dev Handle ERC1155 token receipt for escrow
     */
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        public
        virtual
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }
}
