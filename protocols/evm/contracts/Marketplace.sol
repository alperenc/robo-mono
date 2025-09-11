// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Libraries.sol";
import "./RoboshareTokens.sol";
import "./VehicleRegistry.sol";
import "./PartnerManager.sol";
import "./Treasury.sol";

// Marketplace errors
error Marketplace__ZeroAddress();
error Marketplace__ListingNotFound();
error Marketplace__NotTokenOwner();
error Marketplace__ListingExpired();
error Marketplace__InsufficientPayment();
error Marketplace__InvalidTokenType();
error Marketplace__InvalidAmount();
error Marketplace__ListingNotActive();
error Marketplace__CollateralNotLocked();
error Marketplace__InsufficientTokenBalance();

/**
 * @dev Marketplace for buying and selling revenue share tokens
 * Handles listing creation, purchasing, and fee distribution
 * Integrates with Treasury to ensure collateral is locked before listing
 */
contract Marketplace is 
    Initializable, 
    AccessControlUpgradeable, 
    UUPSUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    // Core contracts
    RoboshareTokens public roboshareTokens;
    VehicleRegistry public vehicleRegistry;
    PartnerManager public partnerManager;
    Treasury public treasury;
    IERC20 public usdcToken;
    
    // Treasury pattern from original protocol
    address public treasuryAddress;
    
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
    mapping(uint256 => uint256[]) public vehicleListings; // vehicleId => listingIds[]
    
    // Events
    event ListingCreated(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        uint256 indexed vehicleId,
        address seller,
        uint256 amount,
        uint256 pricePerToken,
        uint256 expiresAt,
        bool buyerPaysFee
    );
    
    event RevenueTokensTraded(
        uint256 indexed revenueTokenId, 
        address indexed from, 
        address indexed to, 
        uint256 amount,
        uint256 listingId,
        uint256 totalPrice
    );
    
    event ListingCancelled(uint256 indexed listingId, address indexed seller);
    
    event CollateralLockedAndListed(
        uint256 indexed vehicleId,
        uint256 indexed revenueShareTokenId,
        uint256 indexed listingId,
        address partner,
        uint256 collateralAmount,
        uint256 tokensListed,
        uint256 pricePerToken,
        bool buyerPaysFee
    );
    
    event TreasuryAddressUpdated(address oldTreasury, address newTreasury);
    
    /**
     * @dev Initialize the marketplace
     */
    function initialize(
        address _admin,
        address _roboshareTokens,
        address _vehicleRegistry,
        address _partnerManager,
        address _treasury,
        address _usdcToken,
        address _treasuryAddress
    ) public initializer {
        if (
            _admin == address(0) ||
            _roboshareTokens == address(0) ||
            _vehicleRegistry == address(0) ||
            _partnerManager == address(0) ||
            _treasury == address(0) ||
            _usdcToken == address(0) ||
            _treasuryAddress == address(0)
        ) {
            revert Marketplace__ZeroAddress();
        }
        
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        
        roboshareTokens = RoboshareTokens(_roboshareTokens);
        vehicleRegistry = VehicleRegistry(_vehicleRegistry);
        partnerManager = PartnerManager(_partnerManager);
        treasury = Treasury(_treasury);
        usdcToken = IERC20(_usdcToken);
        treasuryAddress = _treasuryAddress;
        
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
     * @dev Lock collateral and create listing in one transaction
     * Prerequisites: Vehicle must be registered and revenue share tokens must already be minted
     * @param vehicleId The ID of the vehicle (tokens should already exist)
     * @param revenueTokenPrice Price per revenue share token in USDC
     * @param totalRevenueTokens Total number of revenue share tokens (for collateral calculation)
     * @param tokensToList Number of tokens to list for sale (must be <= partner's balance)
     * @param listingDuration Duration for the listing in seconds
     * @param buyerPaysFee If true, buyer pays protocol fee; if false, seller absorbs fee
     */
    function lockCollateralAndList(
        uint256 vehicleId,
        uint256 revenueTokenPrice,
        uint256 totalRevenueTokens,
        uint256 tokensToList,
        uint256 listingDuration,
        bool buyerPaysFee
    ) external onlyAuthorizedPartner nonReentrant returns (uint256 listingId) {
        // Validate inputs
        if (tokensToList == 0 || tokensToList > totalRevenueTokens) {
            revert Marketplace__InvalidAmount();
        }
        
        // Get revenue share token ID
        uint256 revenueShareTokenId = vehicleRegistry.getRevenueShareTokenIdFromVehicleId(vehicleId);
        
        // Verify partner owns enough tokens (tokens should already exist from vehicle registration)
        uint256 partnerBalance = roboshareTokens.balanceOf(msg.sender, revenueShareTokenId);
        if (partnerBalance < tokensToList) {
            revert Marketplace__InsufficientTokenBalance();
        }
        
        // Lock collateral in Treasury (requires prior USDC approval)
        treasury.lockCollateral(vehicleId, revenueTokenPrice, totalRevenueTokens);
        
        // Create listing for specified portion of existing tokens
        listingId = _createListing(
            revenueShareTokenId,
            tokensToList,
            revenueTokenPrice,
            listingDuration,
            buyerPaysFee
        );
        
        // Get collateral amount for event
        (, uint256 collateralAmount, , ,) = treasury.getVehicleCollateralInfo(vehicleId);
        
        emit CollateralLockedAndListed(
            vehicleId,
            revenueShareTokenId,
            listingId,
            msg.sender,
            collateralAmount,
            tokensToList,
            revenueTokenPrice,
            buyerPaysFee
        );
        
        return listingId;
    }
    
    /**
     * @dev Create a listing for revenue share tokens (requires collateral to be locked)
     * @param tokenId The revenue share token ID
     * @param amount Number of tokens to list
     * @param pricePerToken Price per token in USDC
     * @param duration Listing duration in seconds  
     * @param buyerPaysFee If true, buyer pays protocol fee; if false, seller absorbs fee
     */
    function createListing(
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerToken,
        uint256 duration,
        bool buyerPaysFee
    ) external nonReentrant returns (uint256 listingId) {
        // Validate token type (must be revenue share token - even number)
        if (tokenId % 2 != 0) {
            revert Marketplace__InvalidTokenType();
        }
        
        // Get vehicle ID and check collateral is locked
        uint256 vehicleId = vehicleRegistry.getVehicleIdFromRevenueShareTokenId(tokenId);
        (, , bool isLocked, ,) = treasury.getVehicleCollateralInfo(vehicleId);
        if (!isLocked) {
            revert Marketplace__CollateralNotLocked();
        }
        
        return _createListing(tokenId, amount, pricePerToken, duration, buyerPaysFee);
    }
    
    /**
     * @dev Internal function to create listing
     */
    function _createListing(
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerToken,
        uint256 duration,
        bool buyerPaysFee
    ) internal returns (uint256 listingId) {
        // Validate amount
        if (amount == 0) {
            revert Marketplace__InvalidAmount();
        }
        
        // Verify seller owns enough tokens
        uint256 sellerBalance = roboshareTokens.balanceOf(msg.sender, tokenId);
        if (sellerBalance < amount) {
            revert Marketplace__NotTokenOwner();
        }
        
        // Get vehicle ID for indexing
        uint256 vehicleId = vehicleRegistry.getVehicleIdFromRevenueShareTokenId(tokenId);
        
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
        
        // Add to vehicle listings index
        vehicleListings[vehicleId].push(listingId);
        
        // Transfer tokens to marketplace for escrow
        roboshareTokens.safeTransferFrom(msg.sender, address(this), tokenId, amount, "");
        
        emit ListingCreated(listingId, tokenId, vehicleId, msg.sender, amount, pricePerToken, expiresAt, buyerPaysFee);
        
        return listingId;
    }
    
    /**
     * @dev Purchase tokens from a listing
     */
    function purchaseListing(uint256 listingId, uint256 amount) external nonReentrant {
        Listing storage listing = listings[listingId];
        
        // Validate listing exists and is active
        if (listing.listingId == 0) {
            revert Marketplace__ListingNotFound();
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
        
        // Calculate payment amounts
        uint256 totalPrice = amount * listing.pricePerToken;
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(totalPrice);
        uint256 expectedPayment = listing.buyerPaysFee ? totalPrice + protocolFee : totalPrice;
        
        // Check buyer has sufficient USDC
        if (usdcToken.balanceOf(msg.sender) < expectedPayment) {
            revert Marketplace__InsufficientPayment();
        }
        
        // Update listing
        listing.amount -= amount;
        if (listing.amount == 0) {
            listing.isActive = false;
        }
        
        // Calculate seller payment based on fee arrangement
        uint256 sellerPayment = listing.buyerPaysFee ? totalPrice : totalPrice - protocolFee;
        
        // Transfer USDC payments
        usdcToken.transferFrom(msg.sender, listing.seller, sellerPayment);
        if (protocolFee > 0) {
            usdcToken.transferFrom(msg.sender, treasuryAddress, protocolFee);
        }
        
        // Transfer tokens to buyer
        roboshareTokens.safeTransferFrom(address(this), msg.sender, listing.tokenId, amount, "");
        
        emit RevenueTokensTraded(
            listing.tokenId,
            listing.seller,
            msg.sender,
            amount,
            listingId,
            totalPrice
        );
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
     * @dev Get active listings for a vehicle
     */
    function getVehicleListings(uint256 vehicleId) external view returns (uint256[] memory activeListings) {
        uint256[] memory allListings = vehicleListings[vehicleId];
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
     * @dev Check if vehicle has locked collateral (required for listing)
     */
    function isVehicleEligibleForListing(uint256 vehicleId) external view returns (bool) {
        (, , bool isLocked, ,) = treasury.getVehicleCollateralInfo(vehicleId);
        return isLocked;
    }
    
    // Admin Functions
    
    /**
     * @dev Update treasury address for protocol fees
     */
    function setTreasuryAddress(address newTreasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) {
            revert Marketplace__ZeroAddress();
        }
        
        address oldTreasury = treasuryAddress;
        treasuryAddress = newTreasury;
        
        emit TreasuryAddressUpdated(oldTreasury, newTreasury);
    }
    
    // UUPS Upgrade authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
    
    /**
     * @dev Handle ERC1155 token receipt for escrow
     */
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
    
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}