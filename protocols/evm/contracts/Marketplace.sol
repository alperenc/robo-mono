// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ProtocolLib, TokenLib, AssetLib } from "./Libraries.sol";
import { ITreasury } from "./interfaces/ITreasury.sol";
import { IMarketplace } from "./interfaces/IMarketplace.sol";
import { RoboshareTokens } from "./RoboshareTokens.sol";
import { PartnerManager } from "./PartnerManager.sol";
import { RegistryRouter } from "./RegistryRouter.sol";

/**
 * @title Marketplace
 * @dev Manages secondary listings and continuous primary pools for revenue tokens.
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

    RoboshareTokens public roboshareTokens;
    PartnerManager public partnerManager;
    RegistryRouter public router;
    ITreasury public treasury;
    IERC20 public usdc;

    uint256 private _listingIdCounter;

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => uint256[]) public assetListings;
    mapping(uint256 => uint256) public tokenEscrow;

    mapping(uint256 => IMarketplace.PrimaryPool) public primaryPools;
    mapping(uint256 => bool) public primaryPoolCreated;

    error ZeroAddress();
    error InvalidTokenType();
    error InvalidPrice();
    error InvalidAmount();
    error InvalidMaxSupply();
    error InsufficientTokenBalance();
    error ListingNotActive();
    error AssetNotActive();
    error AssetNotEligibleForListing();
    error ListingNotFound();
    error FeesExceedPrice();
    error InsufficientPayment();
    error NotListingOwner();
    error InvalidDuration();
    error ListingOwnerCannotPurchase();
    error PrimaryListingRequiresBuyerPaysFee();
    error ListingNotEnded();
    error ListingIsCancelled();
    error ListingNotCancelled();
    error NoTokensToClaim();
    error NoRefundToClaim();
    error InvalidUSDCContract(address token);
    error UnsupportedUSDCDecimals(uint8 decimals);
    error PrimaryListingsDisabled();
    error PrimaryPoolAlreadyCreated();
    error PrimaryPoolNotFound();
    error PrimaryPoolNotActive();
    error PrimaryPoolAlreadyClosed();
    error NotPoolPartner();
    error PrimaryRedemptionNotAllowed();

    event ListingCreated(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        uint256 indexed assetId,
        address seller,
        uint256 amount,
        uint256 pricePerToken,
        uint256 expiresAt,
        bool buyerPaysFee,
        bool isPrimary
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

    event PartnerManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event UsdcUpdated(address indexed oldAddress, address indexed newAddress);
    event RoboshareTokensUpdated(address indexed oldAddress, address indexed newAddress);
    event RouterUpdated(address indexed oldAddress, address indexed newAddress);
    event TreasuryUpdated(address indexed oldAddress, address indexed newAddress);

    event PrimaryPoolCreated(
        uint256 indexed tokenId,
        address indexed partner,
        uint256 pricePerToken,
        uint256 maxSupply,
        bool immediateProceeds,
        bool protectionEnabled
    );
    event PrimaryPoolPaused(uint256 indexed tokenId);
    event PrimaryPoolUnpaused(uint256 indexed tokenId);
    event PrimaryPoolClosed(uint256 indexed tokenId);
    event PrimaryPoolPurchased(
        uint256 indexed tokenId,
        address indexed buyer,
        uint256 amount,
        uint256 totalCost,
        uint256 protocolFee,
        uint256 partnerProceeds,
        uint256 protectionFunding
    );
    event PrimaryPoolRedeemed(
        uint256 indexed tokenId,
        address indexed holder,
        uint256 amountBurned,
        uint256 payout,
        uint256 investorLiquidityAfter
    );

    /**
     * @dev Initializes core dependencies and admin roles.
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
        treasury = ITreasury(_treasury);
        _validateUSDCContract(_usdc);
        usdc = IERC20(_usdc);

        _listingIdCounter = 1;
    }

    /**
     * @dev Creates a primary pool for the caller as partner.
     */
    function createPrimaryPool(
        uint256 tokenId,
        uint256 pricePerToken,
        uint256 maxSupply,
        bool immediateProceeds,
        bool protectionEnabled
    ) external nonReentrant {
        _createPrimaryPoolFor(msg.sender, tokenId, pricePerToken, maxSupply, immediateProceeds, protectionEnabled);
    }

    /**
     * @dev Creates a primary pool on behalf of a partner.
     */
    function createPrimaryPoolFor(
        address partner,
        uint256 tokenId,
        uint256 pricePerToken,
        uint256 maxSupply,
        bool immediateProceeds,
        bool protectionEnabled
    ) external onlyRole(AUTHORIZED_CONTRACT_ROLE) nonReentrant {
        _createPrimaryPoolFor(partner, tokenId, pricePerToken, maxSupply, immediateProceeds, protectionEnabled);
    }

    /**
     * @dev Internal primary pool creation path with validations.
     */
    function _createPrimaryPoolFor(
        address partner,
        uint256 tokenId,
        uint256 pricePerToken,
        uint256 maxSupply,
        bool immediateProceeds,
        bool protectionEnabled
    ) internal {
        if (!TokenLib.isRevenueToken(tokenId)) revert InvalidTokenType();
        if (pricePerToken == 0) revert InvalidPrice();
        if (maxSupply == 0) revert InvalidMaxSupply();
        if (primaryPoolCreated[tokenId]) revert PrimaryPoolAlreadyCreated();

        uint256 assetId = TokenLib.getAssetIdFromTokenId(tokenId);
        if (!isAssetEligibleForListing(assetId)) revert AssetNotEligibleForListing();
        if (roboshareTokens.balanceOf(partner, assetId) == 0) revert NotPoolPartner();

        primaryPools[tokenId] = IMarketplace.PrimaryPool({
            tokenId: tokenId,
            partner: partner,
            pricePerToken: pricePerToken,
            maxSupply: maxSupply,
            immediateProceeds: immediateProceeds,
            protectionEnabled: protectionEnabled,
            isPaused: false,
            isClosed: false,
            createdAt: block.timestamp,
            pausedAt: 0,
            closedAt: 0
        });
        primaryPoolCreated[tokenId] = true;

        emit PrimaryPoolCreated(tokenId, partner, pricePerToken, maxSupply, immediateProceeds, protectionEnabled);
    }

    /**
     * @dev Pauses a primary pool.
     */
    function pausePrimaryPool(uint256 tokenId) external {
        IMarketplace.PrimaryPool storage pool = _getPrimaryPool(tokenId);
        _onlyPoolPartnerOrAdmin(pool.partner);
        if (pool.isClosed) revert PrimaryPoolAlreadyClosed();
        pool.isPaused = true;
        pool.pausedAt = block.timestamp;
        emit PrimaryPoolPaused(tokenId);
    }

    /**
     * @dev Unpauses a previously paused primary pool.
     */
    function unpausePrimaryPool(uint256 tokenId) external {
        IMarketplace.PrimaryPool storage pool = _getPrimaryPool(tokenId);
        _onlyPoolPartnerOrAdmin(pool.partner);
        if (pool.isClosed) revert PrimaryPoolAlreadyClosed();
        pool.isPaused = false;
        emit PrimaryPoolUnpaused(tokenId);
    }

    /**
     * @dev Permanently closes a primary pool.
     */
    function closePrimaryPool(uint256 tokenId) external {
        IMarketplace.PrimaryPool storage pool = _getPrimaryPool(tokenId);
        _onlyPoolPartnerOrAdmin(pool.partner);
        if (pool.isClosed) revert PrimaryPoolAlreadyClosed();
        pool.isClosed = true;
        pool.closedAt = block.timestamp;
        emit PrimaryPoolClosed(tokenId);
    }

    /**
     * @dev Previews primary pool purchase breakdown.
     */
    function previewPrimaryPurchase(uint256 tokenId, uint256 amount)
        external
        view
        returns (uint256 totalCost, uint256 protocolFee, uint256 partnerProceeds, uint256 protectionFunding)
    {
        IMarketplace.PrimaryPool storage pool = _getPrimaryPool(tokenId);
        if (amount == 0) return (0, 0, 0, 0);

        uint256 grossPrincipal = amount * pool.pricePerToken;
        protocolFee = ProtocolLib.calculateProtocolFee(grossPrincipal);
        totalCost = grossPrincipal + protocolFee;

        if (pool.immediateProceeds) {
            partnerProceeds = grossPrincipal;
        }
        protectionFunding = 0;
    }

    /**
     * @dev Buys tokens from a primary pool and settles immediately.
     */
    function buyFromPrimaryPool(uint256 tokenId, uint256 amount) external nonReentrant {
        IMarketplace.PrimaryPool storage pool = _getPrimaryPool(tokenId);
        if (pool.isPaused || pool.isClosed) revert PrimaryPoolNotActive();
        if (amount == 0) revert InvalidAmount();

        uint256 assetId = TokenLib.getAssetIdFromTokenId(tokenId);
        if (!isAssetEligibleForListing(assetId)) revert AssetNotActive();

        uint256 currentSupply = roboshareTokens.getRevenueTokenSupply(tokenId);
        if (currentSupply + amount > pool.maxSupply) revert InvalidAmount();

        uint256 grossPrincipal = amount * pool.pricePerToken;
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(grossPrincipal);
        uint256 totalCost = grossPrincipal + protocolFee;

        if (usdc.balanceOf(msg.sender) < totalCost) revert InsufficientPayment();

        usdc.safeTransferFrom(msg.sender, address(treasury), totalCost);

        (uint256 partnerProceeds, uint256 protectionFunding) = treasury.processPrimaryPoolPurchase(
            msg.sender,
            tokenId,
            amount,
            pool.partner,
            grossPrincipal,
            protocolFee,
            pool.immediateProceeds,
            pool.protectionEnabled
        );

        emit PrimaryPoolPurchased(
            tokenId, msg.sender, amount, totalCost, protocolFee, partnerProceeds, protectionFunding
        );
    }

    /**
     * @dev Previews redemption payout from a primary pool.
     */
    function previewPrimaryRedemption(uint256 tokenId, uint256 amount)
        external
        view
        returns (uint256 payout, uint256 investorLiquidity, uint256 circulatingSupply)
    {
        _getPrimaryPool(tokenId);
        if (amount == 0) return (0, 0, 0);

        circulatingSupply = roboshareTokens.getRevenueTokenSupply(tokenId);
        uint256 assetId = TokenLib.getAssetIdFromTokenId(tokenId);
        investorLiquidity = treasury.getPrimaryInvestorLiquidity(assetId);
        payout = treasury.previewPrimaryRedemptionPayout(assetId, amount, circulatingSupply);
    }

    /**
     * @dev Redeems pool tokens for investor liquidity.
     */
    function redeemPrimaryPool(uint256 tokenId, uint256 amount, uint256 minPayout)
        external
        nonReentrant
        returns (uint256 payout)
    {
        IMarketplace.PrimaryPool storage pool = _getPrimaryPool(tokenId);
        if (pool.isPaused || pool.isClosed) revert PrimaryPoolNotActive();
        if (amount == 0) revert InvalidAmount();

        uint256 assetId = TokenLib.getAssetIdFromTokenId(tokenId);
        if (!isAssetEligibleForListing(assetId)) revert AssetNotActive();

        uint256 circulatingSupply = roboshareTokens.getRevenueTokenSupply(tokenId);
        payout = treasury.processPrimaryRedemption(msg.sender, assetId, amount, circulatingSupply, minPayout);

        uint256 investorLiquidityAfter = treasury.getPrimaryInvestorLiquidity(assetId);
        emit PrimaryPoolRedeemed(tokenId, msg.sender, amount, payout, investorLiquidityAfter);
    }

    /**
     * @dev Creates a secondary listing for caller-owned tokens.
     */
    function createListing(uint256 tokenId, uint256 amount, uint256 pricePerToken, uint256 duration, bool buyerPaysFee)
        external
        nonReentrant
        returns (uint256 listingId)
    {
        return _createListingFor(msg.sender, tokenId, amount, pricePerToken, duration, buyerPaysFee);
    }

    /**
     * @dev Creates a secondary listing on behalf of seller.
     */
    function createListingFor(
        address seller,
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerToken,
        uint256 duration,
        bool buyerPaysFee
    ) external override onlyRole(AUTHORIZED_CONTRACT_ROLE) nonReentrant returns (uint256 listingId) {
        return _createListingFor(seller, tokenId, amount, pricePerToken, duration, buyerPaysFee);
    }

    /**
     * @dev Internal listing creation path.
     */
    function _createListingFor(
        address seller,
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerToken,
        uint256 duration,
        bool buyerPaysFee
    ) internal returns (uint256 listingId) {
        if (!TokenLib.isRevenueToken(tokenId)) revert InvalidTokenType();
        if (pricePerToken == 0) revert InvalidPrice();

        uint256 assetId = TokenLib.getAssetIdFromTokenId(tokenId);
        if (!isAssetEligibleForListing(assetId)) revert AssetNotEligibleForListing();

        uint256 tokenSupply = roboshareTokens.getRevenueTokenSupply(tokenId);
        if (amount == 0 || amount > tokenSupply) revert InvalidAmount();

        uint256 sellerBalance = roboshareTokens.balanceOf(seller, tokenId);
        uint256 earlySalePenalty = 0;

        if (sellerBalance < amount) revert InsufficientTokenBalance();
        earlySalePenalty = roboshareTokens.getSalesPenalty(seller, tokenId, amount);

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
            buyerPaysFee: buyerPaysFee,
            earlySalePenalty: earlySalePenalty,
            isPrimary: false
        });

        assetListings[assetId].push(listingId);
        roboshareTokens.safeTransferFrom(seller, address(this), tokenId, amount, "");

        emit ListingCreated(listingId, tokenId, assetId, seller, amount, pricePerToken, expiresAt, buyerPaysFee, false);
        return listingId;
    }

    /**
     * @dev Purchases tokens from a secondary listing with immediate settlement.
     */
    function purchaseTokens(uint256 listingId, uint256 amount) external nonReentrant {
        Listing storage listing = listings[listingId];
        if (listing.listingId == 0) revert ListingNotFound();

        uint256 assetId = TokenLib.getAssetIdFromTokenId(listing.tokenId);
        if (!isAssetEligibleForListing(assetId)) revert AssetNotActive();
        if (msg.sender == listing.seller) revert ListingOwnerCannotPurchase();
        if (!listing.isActive) revert ListingNotActive();
        if (amount == 0 || amount > listing.amount) revert InvalidAmount();

        uint256 totalPrice = amount * listing.pricePerToken;
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(totalPrice);

        uint256 totalListed = listing.amount + listing.soldAmount;
        uint256 penaltyShare = 0;
        if (listing.earlySalePenalty > 0) {
            penaltyShare = (listing.earlySalePenalty * amount) / totalListed;
        }

        uint256 expectedPayment;
        uint256 sellerReceives;
        uint256 totalFeesToTreasury = protocolFee;

        if (listing.buyerPaysFee) {
            if (penaltyShare > totalPrice) revert FeesExceedPrice();
            expectedPayment = totalPrice + protocolFee;
            sellerReceives = totalPrice - penaltyShare;
            totalFeesToTreasury += penaltyShare;
        } else {
            if (totalFeesToTreasury + penaltyShare > totalPrice) revert FeesExceedPrice();
            expectedPayment = totalPrice;
            sellerReceives = totalPrice - totalFeesToTreasury - penaltyShare;
            totalFeesToTreasury += penaltyShare;
        }

        if (usdc.balanceOf(msg.sender) < expectedPayment) revert InsufficientPayment();

        listing.amount -= amount;
        listing.soldAmount += amount;
        if (listing.amount == 0) {
            listing.isActive = false;
        }

        usdc.safeTransferFrom(msg.sender, address(this), expectedPayment);
        if (sellerReceives > 0) {
            usdc.safeTransfer(listing.seller, sellerReceives);
        }
        if (totalFeesToTreasury > 0) {
            usdc.safeTransfer(address(treasury), totalFeesToTreasury);
            treasury.recordPendingWithdrawal(treasury.treasuryFeeRecipient(), totalFeesToTreasury);
        }

        roboshareTokens.safeTransferFrom(address(this), msg.sender, listing.tokenId, amount, "");

        emit RevenueTokensTraded(listing.tokenId, listing.seller, msg.sender, amount, listingId, totalPrice);
    }

    /**
     * @dev Ends an active listing and returns unsold inventory to seller.
     */
    function endListing(uint256 listingId) public nonReentrant {
        Listing storage listing = listings[listingId];

        if (listing.listingId == 0) revert ListingNotFound();
        if (listing.seller != msg.sender) revert NotListingOwner();

        bool isSoldOut = (!listing.isActive && listing.amount == 0 && !listing.isCancelled);
        if (!listing.isActive && !isSoldOut) revert ListingNotActive();

        listing.isActive = false;

        if (listing.amount > 0) {
            roboshareTokens.safeTransferFrom(address(this), listing.seller, listing.tokenId, listing.amount, "");
            listing.amount = 0;
        }

        emit ListingEnded(listingId, msg.sender);
    }

    /**
     * @dev Cancels an active listing and returns unsold inventory.
     */
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];

        if (listing.listingId == 0) revert ListingNotFound();
        if (listing.seller != msg.sender) {
            if (block.timestamp <= listing.expiresAt) {
                revert NotListingOwner();
            }
        }
        if (!listing.isActive) revert ListingNotActive();

        listing.isActive = false;
        listing.isCancelled = true;

        uint256 totalReturn = listing.amount;
        if (totalReturn > 0) {
            roboshareTokens.safeTransferFrom(address(this), listing.seller, listing.tokenId, totalReturn, "");
        }
        listing.amount = 0;

        emit ListingCancelled(listingId, msg.sender);
    }

    /**
     * @dev Extends expiration for an active listing.
     */
    function extendListing(uint256 listingId, uint256 additionalDuration) external nonReentrant {
        Listing storage listing = listings[listingId];

        if (listing.listingId == 0) revert ListingNotFound();
        if (listing.seller != msg.sender) revert NotListingOwner();
        if (!listing.isActive) revert ListingNotActive();
        if (additionalDuration == 0) revert InvalidDuration();

        listing.expiresAt += additionalDuration;

        emit ListingExtended(listingId, listing.expiresAt);
    }

    /**
     * @dev Clears token escrow balance for authorized orchestrators.
     */
    function clearTokenEscrow(uint256 tokenId) external onlyRole(AUTHORIZED_CONTRACT_ROLE) returns (uint256 amount) {
        amount = tokenEscrow[tokenId];
        if (amount > 0) {
            tokenEscrow[tokenId] = 0;
        }
    }

    /**
     * @dev Credits token escrow balance for authorized orchestrators.
     */
    function creditTokenEscrow(uint256 tokenId, uint256 amount) external onlyRole(AUTHORIZED_CONTRACT_ROLE) {
        if (amount > 0) {
            tokenEscrow[tokenId] += amount;
        }
    }

    /**
     * @dev Returns listing details.
     */
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    /**
     * @dev Returns primary pool details.
     */
    function getPrimaryPool(uint256 tokenId) external view returns (IMarketplace.PrimaryPool memory) {
        return _getPrimaryPool(tokenId);
    }

    /**
     * @dev Returns whether primary pool exists and is active.
     */
    function isPrimaryPoolActive(uint256 tokenId) external view returns (bool) {
        if (!primaryPoolCreated[tokenId]) return false;
        IMarketplace.PrimaryPool storage pool = primaryPools[tokenId];
        return !pool.isPaused && !pool.isClosed;
    }

    /**
     * @dev Returns active listings for an asset.
     */
    function getAssetListings(uint256 assetId) external view returns (uint256[] memory activeListings) {
        uint256[] memory allListings = assetListings[assetId];
        uint256 activeCount = 0;

        for (uint256 i = 0; i < allListings.length; i++) {
            Listing storage listing = listings[allListings[i]];
            if (listing.isActive) {
                activeCount++;
            }
        }

        activeListings = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allListings.length; i++) {
            Listing storage listing = listings[allListings[i]];
            if (listing.isActive) {
                activeListings[index] = allListings[i];
                index++;
            }
        }

        return activeListings;
    }

    /**
     * @dev Calculates purchase cost and fees for listing buy.
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
     * @dev Returns current listing id counter.
     */
    function getCurrentListingId() external view returns (uint256) {
        return _listingIdCounter;
    }

    /**
     * @dev Returns whether asset is eligible for market operations.
     */
    function isAssetEligibleForListing(uint256 assetId) public view override returns (bool) {
        if (!router.assetExists(assetId)) return false;

        AssetLib.AssetStatus status = router.getAssetStatus(assetId);
        if (status != AssetLib.AssetStatus.Active && status != AssetLib.AssetStatus.Earning) return false;

        return true;
    }

    /**
     * @dev Updates PartnerManager reference.
     */
    function updatePartnerManager(address _partnerManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_partnerManager == address(0)) revert ZeroAddress();
        address oldAddress = address(partnerManager);
        partnerManager = PartnerManager(_partnerManager);
        emit PartnerManagerUpdated(oldAddress, _partnerManager);
    }

    /**
     * @dev Updates payment token reference after validation.
     */
    function updateUSDC(address _usdc) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_usdc == address(0)) revert ZeroAddress();
        _validateUSDCContract(_usdc);
        address oldAddress = address(usdc);
        usdc = IERC20(_usdc);
        emit UsdcUpdated(oldAddress, _usdc);
    }

    /**
     * @dev Validates USDC-compatible ERC20 contract (6 decimals).
     */
    function _validateUSDCContract(address token) internal view {
        try IERC20(token).totalSupply() returns (uint256) { }
        catch {
            revert InvalidUSDCContract(token);
        }

        uint8 tokenDecimals;
        try IERC20Metadata(token).decimals() returns (uint8 d) {
            tokenDecimals = d;
        } catch {
            revert InvalidUSDCContract(token);
        }

        if (tokenDecimals != 6) {
            revert UnsupportedUSDCDecimals(tokenDecimals);
        }
    }

    /**
     * @dev Updates RoboshareTokens reference.
     */
    function updateRoboshareTokens(address _roboshareTokens) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_roboshareTokens == address(0)) revert ZeroAddress();
        address oldAddress = address(roboshareTokens);
        roboshareTokens = RoboshareTokens(_roboshareTokens);
        emit RoboshareTokensUpdated(oldAddress, _roboshareTokens);
    }

    /**
     * @dev Updates RegistryRouter reference.
     */
    function updateRouter(address _newRouter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newRouter == address(0)) revert ZeroAddress();
        address oldAddress = address(router);
        router = RegistryRouter(_newRouter);
        emit RouterUpdated(oldAddress, _newRouter);
    }

    /**
     * @dev Updates Treasury reference.
     */
    function updateTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_treasury == address(0)) revert ZeroAddress();
        address oldAddress = address(treasury);
        treasury = ITreasury(_treasury);
        emit TreasuryUpdated(oldAddress, _treasury);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    /**
     * @dev ERC1155 single token receiver hook.
     */
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * @dev ERC1155 batch token receiver hook.
     */
    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        public
        virtual
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function _getPrimaryPool(uint256 tokenId) internal view returns (IMarketplace.PrimaryPool storage pool) {
        if (!primaryPoolCreated[tokenId]) revert PrimaryPoolNotFound();
        pool = primaryPools[tokenId];
    }

    function _onlyPoolPartnerOrAdmin(address partner) internal view {
        if (msg.sender != partner && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert NotPoolPartner();
        }
    }
}
