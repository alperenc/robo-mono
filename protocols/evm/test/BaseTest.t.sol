// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/Marketplace.sol";
import "../contracts/VehicleRegistry.sol";
import "../contracts/RoboshareTokens.sol";
import "../contracts/PartnerManager.sol";
import "../contracts/Treasury.sol";
import "../contracts/Libraries.sol";
import "../script/DeployHelpers.s.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract BaseTest is Test {
    enum SetupState {
        None,
        ContractsDeployed,
        VehicleRegistered,
        RevenueTokensMinted,
        CollateralLockedAndListed
    }

    SetupState private currentState;

    Marketplace public marketplace;
    Marketplace public marketplaceImplementation;
    VehicleRegistry public vehicleRegistry;
    VehicleRegistry public vehicleImplementation;
    RoboshareTokens public roboshareTokens;
    RoboshareTokens public tokenImplementation;
    PartnerManager public partnerManager;
    PartnerManager public partnerImplementation;
    Treasury public treasury;
    Treasury public treasuryImplementation;
    ERC20Mock public usdc;

    ScaffoldETHDeploy public deployHelpers;
    ScaffoldETHDeploy.NetworkConfig public config;

    address public admin = makeAddr("admin");
    address public partner1 = makeAddr("partner1");
    address public partner2 = makeAddr("partner2");
    address public buyer = makeAddr("buyer");
    address public unauthorized = makeAddr("unauthorized");

    // Test vehicle data
    string constant TEST_VIN = "1HGCM82633A123456";
    string constant TEST_MAKE = "Honda";
    string constant TEST_MODEL = "Civic";
    uint256 constant TEST_YEAR = 2024;
    uint256 constant TEST_MANUFACTURER_ID = 1;
    string constant TEST_OPTION_CODES = "EX-L,NAV,HSS";
    string constant TEST_METADATA_URI = "ipfs://QmTestHash123456789abcdefghijklmnopqrstuvwxyzABC";

    string constant PARTNER1_NAME = "RideShare Fleet Co.";
    string constant PARTNER2_NAME = "Urban Delivery Services";

    // Role constants
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Test marketplace parameters
    uint256 constant REVENUE_TOKEN_PRICE = 100 * 10 ** 6; // $100 USDC
    uint256 constant TOTAL_REVENUE_TOKENS = 1000;
    uint256 constant TOKENS_TO_LIST = 500;
    uint256 constant LISTING_DURATION = 30 days;

    // Test state
    uint256 public vehicleId;
    uint256 public revenueShareTokenId;
    uint256 public listingId;

    function _ensureState(SetupState requiredState) internal {
        if (currentState >= requiredState) {
            return;
        }

        if (currentState < SetupState.ContractsDeployed) {
            _deployContracts();
            currentState = SetupState.ContractsDeployed;
        }

        if (requiredState >= SetupState.VehicleRegistered && currentState < SetupState.VehicleRegistered) {
            vm.prank(partner1);
            vehicleId = vehicleRegistry.registerVehicle(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            );
            currentState = SetupState.VehicleRegistered;
        }

        if (requiredState >= SetupState.RevenueTokensMinted && currentState < SetupState.RevenueTokensMinted) {
            vm.prank(partner1);
            revenueShareTokenId = vehicleRegistry.mintRevenueShareTokens(vehicleId, TOTAL_REVENUE_TOKENS);
            currentState = SetupState.RevenueTokensMinted;
        }

        if (
            requiredState >= SetupState.CollateralLockedAndListed && currentState < SetupState.CollateralLockedAndListed
        ) {
            // Approve marketplace to transfer tokens on behalf of partner1
            vm.prank(partner1);
            roboshareTokens.setApprovalForAll(address(marketplace), true);

            // Calculate required collateral
            uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

            vm.startPrank(partner1);
            // Approve USDC for collateral
            usdc.approve(address(treasury), requiredCollateral);
            // Lock collateral and list tokens
            listingId = marketplace.lockCollateralAndList(
                vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS, TOKENS_TO_LIST, LISTING_DURATION, true
            );
            vm.stopPrank();
            currentState = SetupState.CollateralLockedAndListed;
        }
    }

    function _deployContracts() private {
        // Setup network configuration
        deployHelpers = new ScaffoldETHDeploy();
        config = deployHelpers.getActiveNetworkConfig();

        // Cast to ERC20Mock for local testing (we know it's a mock on Anvil)
        usdc = ERC20Mock(config.usdcToken);

        // Deploy RoboshareTokens
        tokenImplementation = new RoboshareTokens();
        bytes memory tokenInitData = abi.encodeWithSignature("initialize(address)", admin);
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImplementation), tokenInitData);
        roboshareTokens = RoboshareTokens(address(tokenProxy));

        // Deploy PartnerManager
        partnerImplementation = new PartnerManager();
        bytes memory partnerInitData = abi.encodeWithSignature("initialize(address)", admin);
        ERC1967Proxy partnerProxy = new ERC1967Proxy(address(partnerImplementation), partnerInitData);
        partnerManager = PartnerManager(address(partnerProxy));
        console.log("PartnerManager proxy address in test:", address(partnerManager));

        // Deploy VehicleRegistry
        vehicleImplementation = new VehicleRegistry();
        bytes memory vehicleInitData = abi.encodeWithSignature(
            "initialize(address,address,address)", admin, address(roboshareTokens), address(partnerManager)
        );
        ERC1967Proxy vehicleProxy = new ERC1967Proxy(address(vehicleImplementation), vehicleInitData);
        vehicleRegistry = VehicleRegistry(address(vehicleProxy));

        // Deploy Treasury
        treasuryImplementation = new Treasury();
        bytes memory treasuryInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address)",
            admin,
            address(partnerManager),
            address(vehicleRegistry),
            address(roboshareTokens),
            address(usdc),
            config.treasuryFeeRecipient
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImplementation), treasuryInitData);
        treasury = Treasury(address(treasuryProxy));
        console.log("Treasury proxy address in test:", address(treasury));

        // Deploy Marketplace
        marketplaceImplementation = new Marketplace();
        bytes memory marketplaceInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address,address)",
            admin,
            address(roboshareTokens),
            address(vehicleRegistry),
            address(partnerManager),
            address(treasury),
            address(usdc),
            config.treasuryFeeRecipient
        );
        ERC1967Proxy marketplaceProxy = new ERC1967Proxy(address(marketplaceImplementation), marketplaceInitData);
        marketplace = Marketplace(address(marketplaceProxy));

        // Setup roles and permissions
        vm.startPrank(admin);
        // Grant MINTER_ROLE to VehicleRegistry for token operations
        roboshareTokens.grantRole(MINTER_ROLE, address(vehicleRegistry));
        // Grant AUTHORIZED_CONTRACT_ROLE to Marketplace for Treasury operations
        treasury.grantRole(treasury.AUTHORIZED_CONTRACT_ROLE(), address(marketplace));
        // Authorize partners
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);
        partnerManager.authorizePartner(partner2, PARTNER2_NAME);
        vm.stopPrank();

        // Fund accounts with USDC (only for local testing)
        if (deployHelpers.isLocalNetwork()) {
            usdc.mint(partner1, 1000000 * 10 ** 6); // 1M USDC
            usdc.mint(partner2, 1000000 * 10 ** 6); // 1M USDC
            usdc.mint(buyer, 1000000 * 10 ** 6); // 1M USDC
        }
    }
}
