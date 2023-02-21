//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interface/IInvestment.sol";
import "hardhat/console.sol";

contract Claiming is Ownable {
    using SafeERC20 for IERC20;

    constructor() {}

    event PoolCreated(
        string _name,
        address _contractAddress,
        uint256 _tokenId,
        uint256 _totalAmount,
        address _rewardToken,
        uint256 _rewardAmount
    );

    event Claimed(uint256 _pid, address _user, uint256 _amount);

    struct PoolInfo {
        string name;
        address contractAddress;
        uint256 tokenId;
        uint256 totalAmount;
        address rewardToken;
        uint256 rewardAmount;
    }

    uint256 public _currentPoolId;
    mapping(uint256 => PoolInfo) public _pools;

    function createPool(
        string memory _name,
        address _contractAddress,
        uint256 _tokenId,
        uint256 _totalAmount,
        address _rewardToken,
        uint256 _rewardAmount
    ) external onlyOwner {
        require(bytes(_name).length != 0, "INVALID_NAME");
        require(_contractAddress != address(0), "INVALID_NFT");
        require(_rewardToken != address(0), "INVALID_TOKEN");
        require(
            _tokenId != 0 && _totalAmount != 0 && _rewardAmount != 0,
            "INVALID_AMOUNT"
        );

        uint256 _id = _getNextCardID();
        _incrementPID();
        IERC20(_rewardToken).transferFrom(
            msg.sender,
            address(this),
            _rewardAmount
        );

        PoolInfo memory newPool;
        newPool.name = _name;
        newPool.contractAddress = _contractAddress;
        newPool.tokenId = _tokenId;
        newPool.totalAmount = _totalAmount;
        newPool.rewardToken = _rewardToken;
        newPool.rewardAmount = _rewardAmount;

        _pools[_id] = newPool;

        emit PoolCreated(
            _name,
            _contractAddress,
            _tokenId,
            _totalAmount,
            _rewardToken,
            _rewardAmount
        );
    }

    function claim(uint256 _pid) external {
        require(_pid <= _currentPoolId, "INVALID_PID");
        PoolInfo memory _currentPool = _pools[_pid];
        console.log("FFFF", _pools[_pid].contractAddress);
        uint256 balance = IERC1155(_currentPool.contractAddress).balanceOf(
            msg.sender,
            _currentPool.tokenId
        );

        uint256 clamingAmount = (_currentPool.rewardAmount * balance) /
            _currentPool.totalAmount;
        require(clamingAmount != 0, "NOT_ENOUGH_TOKENS_TO_CLAIM");
        IInvestment(_currentPool.contractAddress).burn(
            msg.sender,
            _currentPool.tokenId,
            balance
        );
        IERC20(_currentPool.rewardToken).transfer(msg.sender, clamingAmount);

        emit Claimed(_pid, msg.sender, clamingAmount);
    }

    function _getNextCardID() private view returns (uint256) {
        return _currentPoolId + 1;
    }

    function _incrementPID() private {
        _currentPoolId++;
    }
}
