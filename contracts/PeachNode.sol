// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract PeachNode is ERC1155, Ownable, ERC1155Supply {
    
    mapping(uint256 => uint256) gameMintLimit;
    
    constructor() ERC1155("") {}
    
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function setGameMintLimit(uint256[] memory ids, uint256[] memory limits)
        external
        onlyOwner
    {
        require(ids.length == limits.length, "PeachNode: ids and limits length mismatch");
        
        for (uint256 i = 0; i < ids.length; ++i) {
            gameMintLimit[i] = limits[i];
        }
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyOwner
    {
        require(totalSupply(id) + amount <= gameMintLimit[id], "PeachNode: Mint limit reached");   
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < ids.length; ++i) {
            if(totalSupply(ids[i]) + amounts[i] <= gameMintLimit[ids[i]]) {
                revert("PeachNode: Mint limit reached");
            }
        }        
        _mintBatch(to, ids, amounts, data);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
