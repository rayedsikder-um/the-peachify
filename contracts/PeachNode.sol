// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PeachNode is ERC1155, Ownable, ERC1155Supply {
    using SafeERC20 for IERC20; 
    
    mapping(uint256 => uint256) gameMintLimit;

    struct GamePrice {
        uint8[] range;
        uint8[] price;
    }
    
    mapping(uint256 => GamePrice) gamePriceInfo;
    mapping(address => uint256) lastClaimed;
    mapping(uint256 => uint256) rewardRates;

    address token;

    address treasury;
    address team;
    address liquidity;
    
    uint256 public constant rewardPoolPercent = 6000;
    uint256 public constant treasuryPercent = 2000;
    uint256 public constant teamPercent = 500;
    uint256 public constant liquidityPercent = 1500;
    uint256 public constant percentDivider = 10000;
    
    constructor(
        address _token, 
        address _treasury, 
        address _team, 
        address _liquidity) ERC1155("") 
    {
        token = _token;
        treasury = _treasury;
        team = _team;
        liquidity = _liquidity;    
    }
    
    function getGamePrice(uint256 id, uint256 amount) public view returns (uint256){
        require(
            gamePriceInfo[id].range.length != 0 && gamePriceInfo[id].price.length != 0,
            "PeachNode: gamePriceInfo not set");
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
        lastClaimed[msg.sender] = block.timestamp;
        uint256 priceOfGames = price * amount;
        IERC20(token).safeTransferFrom(
            msg.sender, address(this), (priceOfGames * rewardPoolPercent) / percentDivider);
        IERC20(token).safeTransferFrom(
            msg.sender, treasury, (priceOfGames * treasuryPercent) / percentDivider);
        IERC20(token).safeTransferFrom(
            msg.sender, team, (priceOfGames * teamPercent) / percentDivider);
        IERC20(token).safeTransferFrom(
            msg.sender, liquidity, (priceOfGames * liquidityPercent) / percentDivider);
        mint(msg.sender, id, amount, "");
    }

    function claimReward(uint256 id) public {
        require(calculateDays(msg.sender) > 30, "PeachNode: Invalid claim");
        require(rewardRates[id] != 0, "PeachNode: Reward not initialized");
        uint256 reward = (
            balanceOf(msg.sender, id) * calculateDays(msg.sender) * rewardRates[id]) / percentDivider;
        IERC20(token).safeTransfer(msg.sender, reward);
    }

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

    function setRewardRates(uint256[] memory ids, uint256[] memory rates)
        external
        onlyOwner
    {
        require(ids.length == rates.length, "PeachNode: ids and rates length mismatch");
        for (uint256 i = 0; i < ids.length; ++i) {
            rewardRates[ids[i]] = rates[i];
        }        
    }    

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    // Private functions

    function calculateDays(address _claimer) private view returns (uint256) {
        if(block.timestamp - lastClaimed[_claimer] <= 30 * 1 days) {
            revert("PeachNode: Cannot claim before 30 days");
        }
        return (block.timestamp - lastClaimed[_claimer]) / 1 days; 
    }    

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        private
    {
        require(totalSupply(id) + amount <= gameMintLimit[id], "PeachNode: Mint limit reached");   
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        private
    {
        for (uint256 i = 0; i < ids.length; ++i) {
            if(totalSupply(ids[i]) + amounts[i] <= gameMintLimit[ids[i]]) {
                revert("PeachNode: Mint limit reached");
            }
        }        
        _mintBatch(to, ids, amounts, data);
    }    
}
