// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {SimplePriceOracle} from "compound-protocol/contracts/SimplePriceOracle.sol";
import {Unitroller} from "compound-protocol/contracts/Unitroller.sol";
import {Comptroller} from "compound-protocol/contracts/Comptroller.sol";
import {WhitePaperInterestRateModel} from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import {CErc20Delegate} from "compound-protocol/contracts/CErc20Delegate.sol";
import {CErc20Delegator} from "compound-protocol/contracts/CErc20Delegator.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";


contract DeployCompound is Script {

    function run() public {
        vm.startBroadcast(); // fill your private key here!
        // 1 - Init comptroller
        Comptroller comptroller = new Comptroller();
        // 2 - Init price oracle
        SimplePriceOracle simplePriceOracle = new SimplePriceOracle();
        // 3 - Init unitroller
        Unitroller unitroller = new Unitroller();
        // 3.1 - Set pending comptroller for unitroller 
        unitroller._setPendingImplementation(address(comptroller));
        // 3.2 - Call comptroller to become new implementation of unitroller
        comptroller._become(unitroller);
        // 3.3 - Proxy comproller and set price oracle
        Comptroller proxyComptroller = Comptroller(address(unitroller));
        proxyComptroller._setPriceOracle(simplePriceOracle);

        // 4 - Init erc20 (decimal is 18)
        ERC20Token testERC20 = new ERC20Token("TestToken", "TT");
        // 5 - Init intreset model
        WhitePaperInterestRateModel interestModel = new WhitePaperInterestRateModel(0, 0);
        // 6 - Init CErc20 delegate
        CErc20Delegate cErc20Delegate = new CErc20Delegate();
        // 7. - Init CErc20 delegator
        CErc20Delegator cErc20Delegator = new CErc20Delegator(
            address(testERC20),
            proxyComptroller,
            interestModel,
            1, // erc20 decimal - cToken decimal, 10 ** (18 - 18)
            "cTestToken",
            "cTT",
            18,
            payable(msg.sender),
            address(cErc20Delegate),
            ""
        );
        vm.stopBroadcast();
    }
}

contract ERC20Token is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}
}