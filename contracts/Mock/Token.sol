//SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC20, Ownable {
    constructor() ERC20("Vault Token", "VTK") {}

    // Mint function for test
    function mint(address _addr, uint256 amount) external onlyOwner {
        _mint(_addr, amount);
    }
}
