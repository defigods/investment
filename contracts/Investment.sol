//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interface/IInvestment.sol";

contract Investment is ERC1155, ERC2981, Ownable, IInvestment {
    using Strings for uint256;

    event PoolCreated(
        string name,
        uint256 pid,
        address paymentToken,
        uint256 basePrice
    );
    event SetRoyalty(address _receiver, uint96 _feeNumerator);
    event SetPrice(uint256 _id, uint256 _basePrice);
    event SetPaymentToken(uint256 _id, address _token);
    event PurchaseNFT(address indexed _user, uint256 _id, uint256 _amount);
    event Withdrawn(address token, address receiver, uint256 amount);

    struct PoolInfo {
        string name;
        uint256 pid;
        uint256 basePrice;
        address paymentToken;
    }

    uint256 public _currentPoolId = 0;
    mapping(uint256 => PoolInfo) public _pools;
    string public _uri;

    constructor(string memory uri_) ERC1155(uri_) {
        _uri = uri_;
    }

    // set royalty of all NFTs to 5% : feeNumerator = 500
    function setRoyalty(address _receiver, uint96 _feeNumerator)
        external
        onlyOwner
    {
        _setDefaultRoyalty(_receiver, _feeNumerator);

        emit SetRoyalty(_receiver, _feeNumerator);
    }

    function uri(uint256 _id)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return string(abi.encodePacked(_uri, _id.toString()));
    }

    function setURI(string calldata newuri) external onlyOwner {
        _uri = newuri;
    }

    function setPrice(uint256 _pid, uint256 _basePrice) external onlyOwner {
        _pools[_pid].basePrice = _basePrice;

        emit SetPrice(_pid, _basePrice);
    }

    function setPaymentToken(uint256 _pid, address _newAddr)
        external
        onlyOwner
    {
        _pools[_pid].paymentToken = _newAddr;

        emit SetPaymentToken(_pid, _newAddr);
    }

    function createPool(
        string memory name,
        address _paymentToken,
        uint256 _basePrice
    ) external onlyOwner {
        require(bytes(name).length != 0, "INVALID_NAME");

        uint256 _pid = _getNextPID();
        _incrementPID();

        PoolInfo memory _newPool;
        _newPool.name = name;
        _newPool.pid = _pid;
        _newPool.paymentToken = _paymentToken;
        _newPool.basePrice = _basePrice;

        _pools[_pid] = _newPool;

        emit PoolCreated(name, _pid, _paymentToken, _basePrice);
    }

    function purchaseNFT(
        uint256 _pid,
        uint256 _amount,
        bytes memory data
    ) external payable {
        require(_pid <= _currentPoolId, "purchaseNFT: Invalid PID");
        PoolInfo memory pool = _pools[_pid];

        uint256 _price = pool.basePrice * _amount;
        address _paymentToken = pool.paymentToken;
        require(
            _paymentToken == address(0) ||
                IERC20(_paymentToken).allowance(msg.sender, address(this)) >=
                _price,
            "Need to Approve payment"
        );

        if (_paymentToken == address(0)) {
            require(msg.value >= _price, "Not enough funds to purchase");
            uint256 overPrice = msg.value - _price;
            if (overPrice > 0) {
                (bool success, ) = payable(msg.sender).call{value: overPrice}(
                    ""
                );
                require(success, "Failed to send funds");
            }
        } else {
            IERC20(_paymentToken).transferFrom(
                msg.sender,
                address(this),
                _price
            );
        }
        _mint(msg.sender, pool.pid, _amount, data);

        emit PurchaseNFT(msg.sender, pool.pid, _amount);
    }

    function burn(
        address from,
        uint256 id,
        uint256 amount
    ) external override {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "burn: caller is not owner nor approved"
        );
        _burn(from, id, amount);
    }

    function withdraw(
        address token,
        address receiver,
        uint256 amount
    ) external onlyOwner {
        require(receiver != address(0), "INVALID_RECEIVER");

        if (token == address(0)) {
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "Failed to send funds");
        } else {
            IERC20(token).transfer(receiver, amount);
        }

        emit Withdrawn(token, receiver, amount);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _getNextPID() private view returns (uint256) {
        return _currentPoolId + 1;
    }

    function _incrementPID() private {
        _currentPoolId++;
    }
}
