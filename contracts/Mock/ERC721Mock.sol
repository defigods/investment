pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Mock is ERC721 {
    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {}

    mapping(uint256 => string) public nftURI;

    function mint(address account, uint256 id) external {
        _mint(account, id);
    }
}
