// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ProtocolLib, TokenLib, AssetLib } from "./Libraries.sol";
import { IMarketplace } from "./interfaces/IMarketplace.sol";
import { RoboshareTokens } from "./RoboshareTokens.sol";
import { PartnerManager } from "./PartnerManager.sol";
import { RegistryRouter } from "./RegistryRouter.sol";
import { Treasury } from "./Treasury.sol";

/**
 * @dev Marketplace for buying and selling revenue share tokens
 * Handles listing creation, purchasing, and fee distribution
 * Integrates with Treasury to ensure collateral is locked before listing
 */
contract Marketplace is
    IMarketplace,
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant AUTHORIZED_CONTRACT_ROLE = keccak256("AUTHORIZED_CONTRACT_ROLE");

    // Core contracts
    RoboshareTokens public roboshareTokens;
    PartnerManager public partnerManager;
    RegistryRouter public router;
    Treasury public treasury;
    IERC20 public usdc;

    // Listing management
    uint256 private _listingIdCounter;

    struct Listing {
        uint256 listingId;
        uint256 tokenId;
        uint256 amount;
        uint256 soldAmount; // Tokens sold and held in escrow
        uint256 pricePerToken; // Price in USDC (6 decimals)
        address seller;
        uint256 expiresAt;
        bool isActive;
        bool isCancelled;
        uint256 createdAt;
        bool buyerPaysFee; // If true, buyer pays protocol fee; if false, seller absorbs fee
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => uint256[]) public assetListings; // assetId => listingIds[]

    // Deferred proceeds tracking (held until listing ends)
    mapping(uint256 => uint256) public listingProceeds; // listingId => seller proceeds
    mapping(uint256 => uint256) public listingProtocolFees; // listingId => protocol fees

    // Escrow tracking
    mapping(uint256 => mapping(address => uint256)) public buyerTokens; // listingId => buyer => tokenAmount
    mapping(uint256 => mapping(address => uint256)) public buyerPayments; // listingId => buyer => usdcPaid

    // Errors
    error ZeroAddress();
    error InvalidTokenType();
    error InvalidPrice();
    error InvalidAmount();
    error InsufficientTokenBalance();
    error ListingNotActive();
    error AssetNotActive();
    error NoCollateralLocked();
    error ListingNotFound();
    error ListingExpired();
    error FeesExceedPrice();
    error InsufficientPayment();
    error NotListingOwner();
    error InvalidDuration();
    error ListingNotEnded();
    error ListingNotCancelled();
    error NoTokensToClaim();
    error NoRefundToClaim();

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

    event ListingExtended(uint256 indexed listingId, uint256 newExpiresAt);

    event RevenueTokensTraded(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 listingId,
        uint256 totalPrice
    );

    event ListingCancelled(uint256 indexed listingId, address indexed seller);
    event ListingEnded(uint256 indexed listingId, address indexed seller);
    event TokensClaimed(uint256 indexed listingId, address indexed buyer, uint256 amount);
    event RefundClaimed(uint256 indexed listingId, address indexed buyer, uint256 amount);

    event PartnerManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event UsdcUpdated(address indexed oldAddress, address indexed newAddress);
    event RoboshareTokensUpdated(address indexed oldAddress, address indexed newAddress);
    event RouterUpdated(address indexed oldAddress, address indexed newAddress);
    event TreasuryUpdated(address indexed oldAddress, address indexed newAddress);
    event SalesProceedsRecorded(uint256 indexed listingId, address indexed seller, uint256 amount);
    event ProtocolFeeRecorded(uint256 indexed listingId, uint256 amount);
    event ListingSettled(
        uint256 indexed listingId, address indexed seller, uint256 sellerProceeds, uint256 protocolFees
    );

    /**
     * @dev Initialize the marketplace
     */
    function initialize(
        address _admin,
        address _roboshareTokens,
        address _partnerManager,
        address _router,
        address _treasury,
        address _usdc
    ) public initializer {
        if (
            _admin == address(0) || _roboshareTokens == address(0) || _partnerManager == address(0)
                || _router == address(0) || _treasury == address(0) || _usdc == address(0)
        ) {
            revert ZeroAddress();
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
        usdc = IERC20(_usdc);

        _listingIdCounter = 1;
    }

    /**
     * @dev Modifier to ensure only authorized partners can call functions
     */
    modifier onlyAuthorizedPartner() {
        _onlyAuthorizedPartner();
        _;
    }

    function _onlyAuthorizedPartner() internal view {
        if (!partnerManager.isAuthorizedPartner(msg.sender)) {
            revert PartnerManager.UnauthorizedPartner();
        }
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
            revert InvalidTokenType();
        }
        if (pricePerToken == 0) {
            revert InvalidPrice();
        }

        uint256 tokenSupply = roboshareTokens.getRevenueTokenSupply(tokenId);

        // Validate inputs
        if (amount == 0 || amount > tokenSupply) {
            revert InvalidAmount();
        }

        // Verify seller owns enough tokens
        uint256 sellerBalance = roboshareTokens.balanceOf(msg.sender, tokenId);
        if (sellerBalance < amount) {
            revert InsufficientTokenBalance();
        }

        // Get asset ID and check collateral is locked
        uint256 assetId = TokenLib.getAssetIdFromTokenId(tokenId);

        // Check asset status is Active
        if (router.getAssetStatus(assetId) != AssetLib.AssetStatus.Active) {
            revert AssetNotActive();
        }

        (,, bool isLocked,,) = treasury.getAssetCollateralInfo(assetId);
        if (!isLocked) {
            revert NoCollateralLocked();
        }

        return _createListingFor(msg.sender, tokenId, amount, pricePerToken, duration, buyerPaysFee);
    }

    /**
     * @dev Create a listing on behalf of a seller (for authorized contracts like VehicleRegistry)
     * Allows registries to create listings during registerAssetMintAndList flow
     * @param seller The address of the seller
     * @param tokenId The revenue share token ID
     * @param amount Number of tokens to list
     * @param pricePerToken Price per token in USDC
     * @param duration Listing duration in seconds
     * @param buyerPaysFee If true, buyer pays protocol fee
     */
    function createListingFor(
        address seller,
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerToken,
        uint256 duration,
        bool buyerPaysFee
    ) external override onlyRole(AUTHORIZED_CONTRACT_ROLE) nonReentrant returns (uint256 listingId) {
        // Validate token type (must be revenue share token)
        if (!TokenLib.isRevenueToken(tokenId)) {
            revert InvalidTokenType();
        }
        if (pricePerToken == 0) {
            revert InvalidPrice();
        }

        uint256 tokenSupply = roboshareTokens.getRevenueTokenSupply(tokenId);

        // Validate inputs
        if (amount == 0 || amount > tokenSupply) {
            revert InvalidAmount();
        }

        // Verify seller owns enough tokens
        uint256 sellerBalance = roboshareTokens.balanceOf(seller, tokenId);
        if (sellerBalance < amount) {
            revert InsufficientTokenBalance();
        }

        // Get asset ID and check collateral is locked
        uint256 assetId = TokenLib.getAssetIdFromTokenId(tokenId);

        // Check asset status is Active
        if (router.getAssetStatus(assetId) != AssetLib.AssetStatus.Active) {
            revert AssetNotActive();
        }

        (,, bool isLocked,,) = treasury.getAssetCollateralInfo(assetId);
        if (!isLocked) {
            revert NoCollateralLocked();
        }

        return _createListingFor(seller, tokenId, amount, pricePerToken, duration, buyerPaysFee);
    }

    /**
     * @dev Internal function to create listing for a specific seller
     */
    function _createListingFor(
        address seller,
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerToken,
        uint256 duration,
        bool buyerPaysFee
    ) internal returns (uint256 listingId) {
        // Get asset ID for indexing
        uint256 assetId = TokenLib.getAssetIdFromTokenId(tokenId);

        // Create listing
        listingId = _listingIdCounter++;
        uint256 expiresAt = block.timestamp + duration;

        listings[listingId] = Listing({
            listingId: listingId,
            tokenId: tokenId,
            amount: amount,
            soldAmount: 0,
            pricePerToken: pricePerToken,
            seller: seller,
            expiresAt: expiresAt,
            isActive: true,
            isCancelled: false,
            createdAt: block.timestamp,
            buyerPaysFee: buyerPaysFee
        });

        // Add to asset listings index
        assetListings[assetId].push(listingId);

        // Transfer tokens to marketplace for escrow
        roboshareTokens.safeTransferFrom(seller, address(this), tokenId, amount, "");

        emit ListingCreated(listingId, tokenId, assetId, seller, amount, pricePerToken, expiresAt, buyerPaysFee);

        return listingId;
    }

    /**
     * @dev Purchase tokens from a listing
     */
    function purchaseTokens(uint256 listingId, uint256 amount) external nonReentrant {
        Listing storage listing = listings[listingId];

        // Validate listing exists and is active
        if (listing.listingId == 0) {
            revert ListingNotFound();
        }

        // Check asset status
        uint256 assetId = TokenLib.getAssetIdFromTokenId(listing.tokenId);
        if (router.getAssetStatus(assetId) != AssetLib.AssetStatus.Active) {
            revert AssetNotActive();
        }

        if (!listing.isActive) {
            revert ListingNotActive();
        }
        if (block.timestamp > listing.expiresAt) {
            revert ListingExpired();
        }
        if (amount == 0 || amount > listing.amount) {
            revert InvalidAmount();
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
                revert FeesExceedPrice();
            }
            expectedPayment = totalPrice + protocolFee;
            // Seller receives the listed price, but the sales penalty is deducted from their share.
            sellerReceives = totalPrice - salesPenalty;
        } else {
            // Buyer pays only the listed price.
            if (totalFeesToTreasury > totalPrice) {
                revert FeesExceedPrice();
            }
            expectedPayment = totalPrice;
            // Seller receives the listed price, but both protocol fee and sales penalty are deducted.
            sellerReceives = totalPrice - totalFeesToTreasury;
        }

        // Check buyer has sufficient USDC
        if (usdc.balanceOf(msg.sender) < expectedPayment) {
            revert InsufficientPayment();
        }

        // Update listing
        listing.amount -= amount;
        if (listing.amount == 0) {
            listing.isActive = false;
        }

        // Hold USDC in Marketplace (deferred transfer to Treasury)
        uint256 totalPayment = sellerReceives + totalFeesToTreasury;
        usdc.safeTransferFrom(msg.sender, address(this), totalPayment);

        // Accumulate proceeds for this listing
        listingProceeds[listingId] += sellerReceives;
        listingProtocolFees[listingId] += totalFeesToTreasury;

        // Update escrow tracking
        listing.soldAmount += amount;
        buyerTokens[listingId][msg.sender] += amount;
        buyerPayments[listingId][msg.sender] += totalPayment;

        emit RevenueTokensTraded(listing.tokenId, listing.seller, msg.sender, amount, listingId, totalPrice);
        emit SalesProceedsRecorded(listingId, listing.seller, sellerReceives);
        emit ProtocolFeeRecorded(listingId, totalFeesToTreasury);
    }

    /**
     * @dev Ends a listing: returns unsold tokens to seller, settles proceeds to Treasury.
     * Tokens sold are kept in escrow for buyers to claim.
     */
    function endListing(uint256 listingId) public nonReentrant {
        Listing storage listing = listings[listingId];

        if (listing.listingId == 0) revert ListingNotFound();
        if (listing.seller != msg.sender) revert NotListingOwner();

        // Allow ending if:
        // 1. Active
        // 2. Inactive but Sold Out (amount == 0) and Not Cancelled (needs settlement)
        // 3. Expired (regardless of active state)
        bool isSoldOut = (!listing.isActive && listing.amount == 0 && !listing.isCancelled);
        bool isExpired = block.timestamp > listing.expiresAt;

        if (!listing.isActive && !isSoldOut && !isExpired) {
            revert ListingNotActive();
        }

        // Mark as inactive (successfully ended)
        listing.isActive = false;

        // Return *unsold* tokens to seller
        if (listing.amount > 0) {
            roboshareTokens.safeTransferFrom(address(this), listing.seller, listing.tokenId, listing.amount, "");
        }

        // Transfer deferred proceeds to Treasury (making them withdrawable)
        _settleListing(listingId, listing.seller);

        emit ListingEnded(listingId, msg.sender);
    }

    /**
     * @dev Cancel a listing and return ALL tokens (unsold + sold) to seller.
     * Buyers must claim their refund manually.
     */
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];

        // Validate listing exists and caller is seller
        if (listing.listingId == 0) {
            revert ListingNotFound();
        }
        if (listing.seller != msg.sender) {
            revert NotListingOwner();
        }
        if (!listing.isActive) {
            revert ListingNotActive();
        }

        // Mark as inactive AND cancelled
        listing.isActive = false;
        listing.isCancelled = true;

        // Return ALL tokens to seller (unsold + sold/escrowed)
        uint256 totalReturn = listing.amount + listing.soldAmount;
        if (totalReturn > 0) {
            roboshareTokens.safeTransferFrom(address(this), listing.seller, listing.tokenId, totalReturn, "");
        }

        // Clear proceeds (void the sales)
        listingProceeds[listingId] = 0;
        listingProtocolFees[listingId] = 0;

        emit ListingCancelled(listingId, msg.sender);
    }

    /**
     * @dev Finalize a listing: ends listing (if active) and withdraws proceeds from Treasury.
     * Convenience function combining endListing + withdraw.
     * @param listingId The listing ID to finalize
     * @return withdrawn Amount of USDC withdrawn
     */
    function finalizeListing(uint256 listingId) external returns (uint256 withdrawn) {
        Listing storage listing = listings[listingId];

        // Only attempt to end if it's still active or effectively active (expired but state true)
        if (listing.isActive) {
            endListing(listingId);
        }

        // Withdraw all pending proceeds from Treasury (includes this listing's proceeds)
        withdrawn = treasury.processWithdrawalFor(msg.sender);
    }

    /**
     * @dev Internal: Transfer accumulated listing proceeds to Treasury
     * @param listingId The listing ID to settle
     * @param seller The seller address to credit
     */
    function _settleListing(uint256 listingId, address seller) internal {
        uint256 sellerProceeds = listingProceeds[listingId];
        uint256 protocolFees = listingProtocolFees[listingId];

        if (sellerProceeds == 0 && protocolFees == 0) {
            return; // Nothing to settle
        }

        // Clear the mappings
        listingProceeds[listingId] = 0;
        listingProtocolFees[listingId] = 0;

        // Transfer to Treasury and record pending withdrawals
        uint256 totalToTreasury = sellerProceeds + protocolFees;
        usdc.safeTransfer(address(treasury), totalToTreasury);

        if (sellerProceeds > 0) {
            treasury.recordPendingWithdrawal(seller, sellerProceeds);
        }
        if (protocolFees > 0) {
            treasury.recordPendingWithdrawal(treasury.treasuryFeeRecipient(), protocolFees);
        }

        emit ListingSettled(listingId, seller, sellerProceeds, protocolFees);
    }

    /**
     * @dev Claim purchased tokens after a listing has successfully ended.
     */
    function claimTokens(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];

        if (listing.listingId == 0) revert ListingNotFound();
        if (listing.isActive) revert ListingNotEnded();
        if (listing.isCancelled) revert ListingNotEnded(); // Cannot claim tokens if cancelled

        uint256 amount = buyerTokens[listingId][msg.sender];
        if (amount == 0) revert NoTokensToClaim();

        // Clear state before transfer
        buyerTokens[listingId][msg.sender] = 0;

        // Transfer tokens
        roboshareTokens.safeTransferFrom(address(this), msg.sender, listing.tokenId, amount, "");

        emit TokensClaimed(listingId, msg.sender, amount);
    }

    /**
     * @dev Claim refund (USDC) if a listing was cancelled.
     */
    function claimRefund(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];

        if (listing.listingId == 0) revert ListingNotFound();
        if (!listing.isCancelled) revert ListingNotCancelled();

        uint256 refundAmount = buyerPayments[listingId][msg.sender];
        if (refundAmount == 0) revert NoRefundToClaim();

        // Clear state before transfer
        buyerPayments[listingId][msg.sender] = 0;

        // Transfer USDC refund
        usdc.safeTransfer(msg.sender, refundAmount);

        emit RefundClaimed(listingId, msg.sender, refundAmount);
    }

    /**
     * @dev Extend the duration of an active listing
     * @param listingId The listing ID to extend
     * @param additionalDuration Additional duration in seconds
     */
    function extendListing(uint256 listingId, uint256 additionalDuration) external nonReentrant {
        Listing storage listing = listings[listingId];

        // Validate listing exists
        if (listing.listingId == 0) {
            revert ListingNotFound();
        }
        // Validate caller is the seller
        if (listing.seller != msg.sender) {
            revert NotListingOwner();
        }
        // Validate listing is active
        if (!listing.isActive) {
            revert ListingNotActive();
        }
        // Validate duration is non-zero
        if (additionalDuration == 0) {
            revert InvalidDuration();
        }

        // Extend the expiration
        listing.expiresAt += additionalDuration;

        emit ListingExtended(listingId, listing.expiresAt);
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
     * @dev Update partner manager reference
     * @param _partnerManager New partner manager address
     */
    function updatePartnerManager(address _partnerManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_partnerManager == address(0)) {
            revert ZeroAddress();
        }
        address oldAddress = address(partnerManager);
        partnerManager = PartnerManager(_partnerManager);
        emit PartnerManagerUpdated(oldAddress, _partnerManager);
    }

    /**
     * @dev Update USDC token reference
     * @param _usdc New USDC token address
     */
    function updateUSDC(address _usdc) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_usdc == address(0)) {
            revert ZeroAddress();
        }
        address oldAddress = address(usdc);
        usdc = IERC20(_usdc);
        emit UsdcUpdated(oldAddress, _usdc);
    }

    /**
     * @dev Update RoboshareTokens contract reference (for upgrades)
     * @param _roboshareTokens New RoboshareTokens contract address
     */
    function updateRoboshareTokens(address _roboshareTokens) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_roboshareTokens == address(0)) {
            revert ZeroAddress();
        }
        address oldAddress = address(roboshareTokens);
        roboshareTokens = RoboshareTokens(_roboshareTokens);
        emit RoboshareTokensUpdated(oldAddress, _roboshareTokens);
    }

    /**
     * @dev Updates the router contract address.
     * Only callable by an admin.
     * @param _newRouter The address of the new router contract.
     */
    function updateRouter(address _newRouter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newRouter == address(0)) {
            revert ZeroAddress();
        }
        address oldAddress = address(router);
        router = RegistryRouter(_newRouter);
        emit RouterUpdated(oldAddress, _newRouter);
    }

    /**
     * @dev Update Treasury contract reference (for upgrades)
     * @param _treasury New Treasury contract address
     */
    function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_treasury == address(0)) {
            revert ZeroAddress();
        }
        address oldAddress = address(treasury);
        treasury = Treasury(_treasury);
        emit TreasuryUpdated(oldAddress, _treasury);
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
