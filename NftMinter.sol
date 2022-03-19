// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNFT is ERC721("NftStakeTest", "NST") {
    uint256 public mintCount = 0;
    uint256 public totalSupply = 8888;

    bool public minted = false;

    mapping(address => uint256) public mintAmount;

    function Mint(
        address to,
        uint256 tokenId,
        string memory tokenURI
    ) public {
        require(minted != true, "All NFTs Minted");
        require(mintAmount[msg.sender] < 20, "Caller is Minting More Than 20");

        _mint(to, tokenId, tokenURI);

        mintCount += 1;
        mintAmount[msg.sender] += 1;

        if (mintCount >= totalSupply) {
            minted = true;
        }
    }
}
