
/*
Oss token generated by Osschain.com
*/

// SPDX-License-Identifier: No License

pragma solidity 0.8.7;

import "./ERC20.sol";
import "./ERC20Burnable.sol";
import "./Ownable.sol"; 
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";
import "./IUniswapV2Router01.sol";
import "./IUniswapV2Router02.sol";

contract Ossly is ERC20, ERC20Burnable, Ownable {
    
    address public developersAddress;
    uint16[3] public developersFees;

    address public marketingAddress;
    uint16[3] public marketingFees;

    address public liquidityAddress;
    uint16[3] public liquidityFees;

    mapping (address => bool) public isExcludedFromFees;

    uint16[3] public totalFees;
    bool private _swapping;

    IUniswapV2Router02 public routerV2;
    address public pairV2;
    mapping (address => bool) public AMMPairs;
 
    event developersAddressUpdated(address developersAddress);
    event developersFeesUpdated(uint16 buyFee, uint16 sellFee, uint16 transferFee);
    event developersFeeSent(address recipient, uint256 amount);

    event marketingAddressUpdated(address marketingAddress);
    event marketingFeesUpdated(uint16 buyFee, uint16 sellFee, uint16 transferFee);
    event marketingFeeSent(address recipient, uint256 amount);

    event liquidityAddressUpdated(address liquidityAddress);
    event liquidityFeesUpdated(uint16 buyFee, uint16 sellFee, uint16 transferFee);
    event liquidityFeeSent(address recipient, uint256 amount);

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event RouterV2Updated(address indexed routerV2);
    event AMMPairsUpdated(address indexed AMMPair, bool isPair);
 
    constructor()
        ERC20(unicode"Ossly", unicode"OSS") 
    {
        address supplyRecipient = 0x06969f6E326E6EAb97Dc69e75dCbAa455e1A2934;
        
        developersAddressSetup(0xfB02f1bce8d4d7E515F224fCa49D2412b706D112);
        developersFeesSetup(30, 30, 30);

        marketingAddressSetup(0xfFf5b259B87d849946D4e2fE7754a75400220AbE);
        marketingFeesSetup(20, 20, 20);

        liquidityAddressSetup(0xD4f56AC6018ec132FC88a4Af921F37D0C1F1aF3a);
        liquidityFeesSetup(20, 20, 20);

        excludeFromFees(supplyRecipient, true);
        excludeFromFees(address(this), true); 

        _updateRouterV2(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        _mint(supplyRecipient, 51000000 * (10 ** decimals()));
        _transferOwnership(0x06969f6E326E6EAb97Dc69e75dCbAa455e1A2934);
    }

    receive() external payable {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }
    
    function _sendInTokens(address from, address to, uint256 amount) private {
        super._transfer(from, to, amount);
    }

    function developersAddressSetup(address _newAddress) public onlyOwner {
        developersAddress = _newAddress;

        excludeFromFees(_newAddress, true);

        emit developersAddressUpdated(_newAddress);
    }

    function developersFeesSetup(uint16 _buyFee, uint16 _sellFee, uint16 _transferFee) public onlyOwner {
        developersFees = [_buyFee, _sellFee, _transferFee];

        totalFees[0] = 0 + developersFees[0] + marketingFees[0] + liquidityFees[0];
        totalFees[1] = 0 + developersFees[1] + marketingFees[1] + liquidityFees[1];
        totalFees[2] = 0 + developersFees[2] + marketingFees[2] + liquidityFees[2];
        require(totalFees[0] <= 2500 && totalFees[1] <= 2500 && totalFees[2] <= 2500, "TaxesDefaultRouter: Cannot exceed max total fee of 25%");

        emit developersFeesUpdated(_buyFee, _sellFee, _transferFee);
    }

    function marketingAddressSetup(address _newAddress) public onlyOwner {
        marketingAddress = _newAddress;

        excludeFromFees(_newAddress, true);

        emit marketingAddressUpdated(_newAddress);
    }

    function marketingFeesSetup(uint16 _buyFee, uint16 _sellFee, uint16 _transferFee) public onlyOwner {
        marketingFees = [_buyFee, _sellFee, _transferFee];

        totalFees[0] = 0 + developersFees[0] + marketingFees[0] + liquidityFees[0];
        totalFees[1] = 0 + developersFees[1] + marketingFees[1] + liquidityFees[1];
        totalFees[2] = 0 + developersFees[2] + marketingFees[2] + liquidityFees[2];
        require(totalFees[0] <= 2500 && totalFees[1] <= 2500 && totalFees[2] <= 2500, "TaxesDefaultRouter: Cannot exceed max total fee of 25%");

        emit marketingFeesUpdated(_buyFee, _sellFee, _transferFee);
    }

    function liquidityAddressSetup(address _newAddress) public onlyOwner {
        liquidityAddress = _newAddress;

        excludeFromFees(_newAddress, true);

        emit liquidityAddressUpdated(_newAddress);
    }

    function liquidityFeesSetup(uint16 _buyFee, uint16 _sellFee, uint16 _transferFee) public onlyOwner {
        liquidityFees = [_buyFee, _sellFee, _transferFee];

        totalFees[0] = 0 + developersFees[0] + marketingFees[0] + liquidityFees[0];
        totalFees[1] = 0 + developersFees[1] + marketingFees[1] + liquidityFees[1];
        totalFees[2] = 0 + developersFees[2] + marketingFees[2] + liquidityFees[2];
        require(totalFees[0] <= 2500 && totalFees[1] <= 2500 && totalFees[2] <= 2500, "TaxesDefaultRouter: Cannot exceed max total fee of 25%");

        emit liquidityFeesUpdated(_buyFee, _sellFee, _transferFee);
    }

    function excludeFromFees(address account, bool isExcluded) public onlyOwner {
        isExcludedFromFees[account] = isExcluded;
        
        emit ExcludeFromFees(account, isExcluded);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        
        if (!_swapping && amount > 0 && to != address(routerV2) && !isExcludedFromFees[from] && !isExcludedFromFees[to]) {
            uint256 fees = 0;
            uint8 txType = 3;
            
            if (AMMPairs[from]) {
                if (totalFees[0] > 0) txType = 0;
            }
            else if (AMMPairs[to]) {
                if (totalFees[1] > 0) txType = 1;
            }
            else if (totalFees[2] > 0) txType = 2;
            
            if (txType < 3) {
                
                uint256 developersPortion = 0;

                uint256 marketingPortion = 0;

                uint256 liquidityPortion = 0;

                fees = amount * totalFees[txType] / 10000;
                amount -= fees;
                
                if (developersFees[txType] > 0) {
                    developersPortion = fees * developersFees[txType] / totalFees[txType];
                    _sendInTokens(from, developersAddress, developersPortion);
                    emit developersFeeSent(developersAddress, developersPortion);
                }

                if (marketingFees[txType] > 0) {
                    marketingPortion = fees * marketingFees[txType] / totalFees[txType];
                    _sendInTokens(from, marketingAddress, marketingPortion);
                    emit marketingFeeSent(marketingAddress, marketingPortion);
                }

                if (liquidityFees[txType] > 0) {
                    liquidityPortion = fees * liquidityFees[txType] / totalFees[txType];
                    _sendInTokens(from, liquidityAddress, liquidityPortion);
                    emit liquidityFeeSent(liquidityAddress, liquidityPortion);
                }

                fees = fees - developersPortion - marketingPortion - liquidityPortion;
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }
        }
        
        super._transfer(from, to, amount);
        
    }

    function _updateRouterV2(address router) private {
        routerV2 = IUniswapV2Router02(router);
        pairV2 = IUniswapV2Factory(routerV2.factory()).createPair(address(this), routerV2.WETH());
        
        _setAMMPair(pairV2, true);

        emit RouterV2Updated(router);
    }

    function setAMMPair(address pair, bool isPair) public onlyOwner {
        require(pair != pairV2, "DefaultRouter: Cannot remove initial pair from list");

        _setAMMPair(pair, isPair);
    }

    function _setAMMPair(address pair, bool isPair) private {
        AMMPairs[pair] = isPair;

        if (isPair) { 
        }

        emit AMMPairsUpdated(pair, isPair);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        super._afterTokenTransfer(from, to, amount);
    }
}
