// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {SimplePriceOracle} from "compound-protocol/contracts/SimplePriceOracle.sol";
import {Unitroller} from "compound-protocol/contracts/Unitroller.sol";
import {ComptrollerG7} from "compound-protocol/contracts/ComptrollerG7.sol";
import {WhitePaperInterestRateModel} from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import {CErc20Delegate} from "compound-protocol/contracts/CErc20Delegate.sol";
import {CErc20Delegator} from "compound-protocol/contracts/CErc20Delegator.sol";
import {CToken} from "compound-protocol/contracts/CToken.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract CompoundSetUp {
    TokenA tokenA;
    TokenB tokenB;
    ComptrollerG7 comptroller;
    ComptrollerG7 comptrollerProxy;
    CErc20Delegator cTokenA;
    CErc20Delegator cTokenB;
    CErc20Delegate cTokenImp;
    WhitePaperInterestRateModel intresetModel;
    Unitroller unitroller;
    SimplePriceOracle oracle;

    function deployCompound() internal {
        tokenA = new TokenA();
        tokenB = new TokenB();
        cTokenImp = new CErc20Delegate();
        intresetModel = new WhitePaperInterestRateModel(0, 0);
        comptroller = new ComptrollerG7();
        unitroller = new Unitroller();
        oracle = new SimplePriceOracle();

        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        
        comptrollerProxy = ComptrollerG7(address(unitroller));
        comptrollerProxy._setPriceOracle(oracle);
        comptrollerProxy._setCloseFactor(5e17);
        comptrollerProxy._setLiquidationIncentive(108 * 1e16);

        setUpTokenA();
        setUpTokenB();
    }

    function setUpTokenA() internal {
        cTokenA = new CErc20Delegator(
            address(tokenA),
            comptrollerProxy,
            intresetModel,
            1e18,
            "CTokenA",
            "cTA",
            18,
            payable(msg.sender),
            address(cTokenImp),
            new bytes(0)
        );
        comptrollerProxy._supportMarket(CToken(address(cTokenA)));
        oracle.setUnderlyingPrice(CToken(address(cTokenA)), 1e18);
    }

    function setUpTokenB() internal {
        cTokenB = new CErc20Delegator(
            address(tokenB),
            comptrollerProxy,
            intresetModel,
            1e18,
            "CTokenB",
            "cTB",
            18,
            payable(msg.sender),
            address(cTokenImp),
            new bytes(0)
        );
        comptrollerProxy._supportMarket(CToken(address(cTokenB)));
        oracle.setUnderlyingPrice(CToken(address(cTokenB)), 1e20);
        comptrollerProxy._setCollateralFactor(CToken(address(cTokenB)), 5e17);
    }
}

contract TokenA is ERC20 {
    constructor() ERC20("TokenA", "TokenA") {}

    function freeMint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}

contract TokenB is ERC20 {
    constructor() ERC20("TokenB", "TokenB") {}

      function freeMint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}