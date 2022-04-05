// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract PeachNode is ERC1155, Ownable, ERC1155Supply {
    
    mapping(uint256 => uint256) gameMintLimit;

    struct GamePrice {
        uint8[] range;
        uint8[] price;
    }
    
    mapping(uint256 => GamePrice) gamePriceInfo;
    mapping(address => uint256) lastClaimed;

    address treasury;
    address team;
    address liquidity;
    
    uint256 public constant rewardPoolPercent = 6000;
    uint256 public constant treasuryPercent = 2000;
    uint256 public constant teamPercent = 500;
    uint256 public constant liquidityPercent = 1500;
    uint256 public constant percentDivider = 10000;
    
    constructor() ERC1155("") {}
    
    function getGamePrice(uint256 id, uint256 amount) public view returns (uint256){
        GamePrice memory gamePrice = gamePriceInfo[id];
        if (amount == 1) {
            return gamePrice.price[0];
        }
        for (uint256 i = 0; i < gamePrice.range.length; ++i) {
            if (i+1 != gamePrice.range.length) {
                if (amount > gamePrice.range[i] && amount <= gamePrice.range[i+1]) {
                    return gamePrice.price[i];
                }
            }
            else {
                return gamePrice.price[i-1];
            }
        }  
    }

    function buyGame(uint256 id, uint256 amount) public {
        uint256 price = getGamePrice(id, amount);
        IERC20(token).safeTransferFrom(msg.sender, address(this), price * amount * rewardPoolPercent / percentDivider);
        IERC20(token).safeTransferFrom(msg.sender, treasury, price * amount * treasury / percentDivider);
        IERC20(token).safeTransferFrom(msg.sender, team, price * amount * team / percentDivider);
        IERC20(token).safeTransferFrom(msg.sender, liquidity, price * amount * liquidity / percentDivider);
        mint(msg.sender, id, amount, "");
    }

    function claimReward() public {
        
    }

    function calculateDays(address _claimer) private returns (uint256) {
        if(lastClaimed[_claimer] <= 30 * 1 days) {
            revert("PeachNode: Cannot claim before 30 days");
        }
        return (block.timestamp - lastClaimed) / 1 days; 
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        internal
    {
        require(totalSupply(id) + amount <= gameMintLimit[id], "PeachNode: Mint limit reached");   
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
    {
        for (uint256 i = 0; i < ids.length; ++i) {
            if(totalSupply(ids[i]) + amounts[i] <= gameMintLimit[ids[i]]) {
                revert("PeachNode: Mint limit reached");
            }
        }        
        _mintBatch(to, ids, amounts, data);
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

    function setGamePriceInfo(uint256[] memory ids, uint8[][] memory ranges, uint8[][] memory prices)
        external
        onlyOwner
    {
        require(ids.length == ranges.length, "PeachNode: ids and ranges length mismatch");
        require(ranges.length == prices.length, "PeachNode: ranges and prices length mismatch");

        for (uint256 i = 0; i < ranges.length; ++i) {
            gamePriceInfo[ids[i]].range = ranges[i];
            gamePriceInfo[ids[i]].price = prices[i];
        }
    }    

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
