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
    CErc20Delegate impl;
    WhitePaperInterestRateModel model;
    Unitroller unitroller;
    SimplePriceOracle oracle;

    function deployCompound() internal {
        tokenA = new TokenA();
        tokenB = new TokenB();
        impl = new CErc20Delegate();
        model = new WhitePaperInterestRateModel(0, 0);
        comptroller = new ComptrollerG7();
        unitroller = new Unitroller();
        oracle = new SimplePriceOracle();

        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        
        comptrollerProxy = ComptrollerG7(address(unitroller));
        comptrollerProxy._setPriceOracle(oracle);

        setUpTokenA();
        setUpTokenA();
    }

    function setUpTokenA() internal {
        cTokenA = new CErc20Delegator(
            address(tokenA),
            comptrollerProxy,
            model,
            1e18,
            "CTokenA",
            "cTA",
            18,
            payable(msg.sender),
            address(impl),
            new bytes(0)
        );
        comptrollerProxy._supportMarket(CToken(address(cTokenA)));
    }

    function setUpTokenB() internal {
        cTokenB = new CErc20Delegator(
            address(tokenB),
            comptrollerProxy,
            model,
            1e18,
            "CTokenB",
            "cTB",
            18,
            payable(msg.sender),
            address(impl),
            new bytes(0)
        );
        comptrollerProxy._supportMarket(CToken(address(cTokenB)));
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