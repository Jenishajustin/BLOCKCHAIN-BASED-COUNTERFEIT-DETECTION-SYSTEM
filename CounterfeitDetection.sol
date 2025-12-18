// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title CounterfeitDetectionFixed
 * @notice A secure and gas-efficient smart contract for product tracking.
 * It uses Events for historical data logging to prevent gas/storage issues.
 */
contract CounterfeitDetectionFixed {

    address public manufacturer;

    // --- Product Structure ---
    struct Product {
        string uniqueProductId;     // Unique ID/Serial Number
        address currentOwner;       // Entity currently holding custody (Manufacturer, Distributor, Retailer, etc.)
        uint256 registrationTimestamp;
        bool isGenuine;             // Set to true upon initial registration
        string status;              // Current physical status (e.g., "Shipped", "In Stock")
        string detailsUri;          // URI/Link to off-chain data (production batch, images)
    }

    mapping(string => Product) public products;

    // --- Events (The Gas-Efficient Way to Store History) ---
    // Off-chain applications will monitor and aggregate these events for the product history display.
    event ProductRegistered(
        string indexed _productId,
        address indexed _manufacturer,
        uint256 _timestamp,
        string _detailsUri
    );

    event StatusUpdated(
        string indexed _productId,
        address indexed _oldOwner,
        address indexed _newOwner,
        string _newStatus,
        uint256 _timestamp
    );

    // --- Modifiers (Access Control) ---
    modifier onlyManufacturer() {
        require(msg.sender == manufacturer, "CD: Caller is not the Manufacturer.");
        _;
    }

    modifier productMustExist(string memory _productId) {
        // Checking length is safer than checking for address(0) for a string key
        require(bytes(products[_productId].uniqueProductId).length > 0, "CD: Product ID does not exist.");
        _;
    }

    modifier onlyCurrentOwner(string memory _productId) {
        require(products[_productId].currentOwner == msg.sender, "CD: Caller is not the current product owner.");
        _;
    }

    // --- Constructor ---
    constructor() {
        manufacturer = msg.sender;
    }

    // --- Core Functions ---

    /**
     * @notice Registers a new product. Only Manufacturer can call this.
     * @param _productId The unique digital identity.
     * @param _detailsUri Link/hash to relevant off-chain product data.
     */
    function registerProduct(string memory _productId, string memory _detailsUri)
        public
        onlyManufacturer
    {
        // **FIX 1: Input Validation** - Product ID must not be empty.
        require(bytes(_productId).length > 0, "CD: Product ID cannot be empty.");
        // Prevent re-registration
        require(bytes(products[_productId].uniqueProductId).length == 0, "CD: Product ID already exists.");

        products[_productId] = Product({
            uniqueProductId: _productId,
            currentOwner: manufacturer,
            registrationTimestamp: block.timestamp,
            isGenuine: true,
            status: "Registered at Manufacturing",
            detailsUri: _detailsUri
        });

        // **FIX 2: Use Event for logging** - History is recorded off-chain via this Event.
        emit ProductRegistered(_productId, manufacturer, block.timestamp, _detailsUri);
    }

    /**
     * @notice Updates status and transfers ownership to the next entity.
     * @param _productId The ID of the product.
     * @param _newStatus A description of the update.
     * @param _newOwner The address of the next entity taking custody.
     */
    function transferAndUpdateStatus(
        string memory _productId,
        string memory _newStatus,
        address _newOwner
    )
        public
        productMustExist(_productId)
        onlyCurrentOwner(_productId)
    {
        // **FIX 3: Input Validation** - New owner must not be the zero address.
        require(_newOwner != address(0), "CD: New owner address cannot be zero.");
        // **FIX 4: Input Validation** - New status must not be empty.
        require(bytes(_newStatus).length > 0, "CD: Status cannot be empty.");

        address oldOwner = msg.sender;

        // 1. Update status
        products[_productId].status = _newStatus;

        // 2. Transfer ownership
        products[_productId].currentOwner = _newOwner;

        // **FIX 5: Use Event for logging** - History is recorded off-chain via this Event.
        emit StatusUpdated(_productId, oldOwner, _newOwner, _newStatus, block.timestamp);
    }

    /**
     * @notice Allows any party (consumers) to verify a product's authenticity and current status.
     * NOTE: Consumer verification system must query the **Events** (ProductRegistered and StatusUpdated) 
     * in addition to this function to get the complete history.
     */
    function verifyProduct(string memory _productId)
        public
        view
        productMustExist(_productId)
        returns (
            bool isGenuine,
            string memory status,
            address currentOwner,
            string memory detailsUri,
            uint256 registrationTimestamp
        )
    {
        Product storage p = products[_productId];
        return (
            p.isGenuine,
            p.status,
            p.currentOwner,
            p.detailsUri,
            p.registrationTimestamp
        );
    }
}