// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SimplePriceOracle} from "compound-protocol/contracts/SimplePriceOracle.sol";
import {Unitroller} from "compound-protocol/contracts/Unitroller.sol";
import {ComptrollerG7} from "compound-protocol/contracts/ComptrollerG7.sol";
import {WhitePaperInterestRateModel} from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import {CErc20Delegate} from "compound-protocol/contracts/CErc20Delegate.sol";
import {CErc20Delegator} from "compound-protocol/contracts/CErc20Delegator.sol";
import {CToken} from "compound-protocol/contracts/CToken.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";



contract FlashLoanTest is Test {
    address admin = makeAddr("Admin");
    address maker = makeAddr("Maker");
    address taker = makeAddr("Taker"); // user1
    address liquidator = makeAddr("Liquidator"); // user2

    uint256 initialUSDCAmount = 5_000 * 1e6;
    uint256 initialUNIAmount = 1_000 * 1e18;

    address _USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address _UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    ERC20 usdc = ERC20(_USDC);
    ERC20 uni = ERC20(_UNI);

    ComptrollerG7 comptroller;
    ComptrollerG7 comptrollerProxy;
    CErc20Delegator cUSDC;
    CErc20Delegator cUNI;
    CErc20Delegate impl;
    WhitePaperInterestRateModel insterestRateModel;
    Unitroller unitroller;
    SimplePriceOracle priceOracle;

    function setUp() public {
        vm.createSelectFork("mainnet rpc end point", 17465000);


        vm.startPrank(admin);
        impl = new CErc20Delegate();
        insterestRateModel = new WhitePaperInterestRateModel(0, 0);
        comptroller = new ComptrollerG7();
        unitroller = new Unitroller();
        priceOracle = new SimplePriceOracle();

        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        comptrollerProxy = ComptrollerG7(address(unitroller));

        comptrollerProxy._setCloseFactor(5e17); // 50%
        comptrollerProxy._setLiquidationIncentive(1.08 * 1e18); // 8%
        comptrollerProxy._setPriceOracle(priceOracle);

        cUSDC = new CErc20Delegator(
            _USDC,
            comptrollerProxy,
            insterestRateModel,
            1e6,
            "Compound USDC",
            "cUSDC",
            18,
            payable(admin),
            address(impl),
            new bytes(0)
        );
        comptrollerProxy._supportMarket(CToken(address(cUSDC)));

        cUNI = new CErc20Delegator(
            _UNI,
            comptrollerProxy,
            insterestRateModel,
            1e18,
            "Compound UNI",
            "cUNI",
            18,
            payable(admin),
            address(impl),
            new bytes(0)
        );
        comptrollerProxy._supportMarket(CToken(address(cUNI)));
        
        priceOracle.setUnderlyingPrice(CToken(address(cUSDC)), 1e30); // $1
        priceOracle.setUnderlyingPrice(CToken(address(cUNI)), 5e18); // $5
        comptrollerProxy._setCollateralFactor(CToken(address(cUNI)), 5e17); // 50%
        comptrollerProxy._supportMarket(CToken(address(cUSDC)));
        comptrollerProxy._supportMarket(CToken(address(cUNI)));

        vm.stopPrank();

        deal(_USDC, maker, initialUSDCAmount);
        deal(_UNI, taker, initialUNIAmount);

        vm.startPrank(maker);
        usdc.approve(address(cUSDC), initialUSDCAmount);
        cUSDC.mint(initialUSDCAmount);
        vm.stopPrank();
    }

    function test_FlasLoanLiqudation() public {
        vm.startPrank(taker);
        uni.approve(address(cUNI), initialUNIAmount);
        cUNI.mint(initialUNIAmount);
        
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cUNI);
        comptrollerProxy.enterMarkets(cTokens);

        cUSDC.borrow(2500 * 1e6);
        vm.stopPrank();

        vm.startPrank(admin);
        priceOracle.setUnderlyingPrice(CToken(address(cUNI)), 4e18); // $5 -> $4
        vm.stopPrank();

        vm.startPrank(liquidator);
         (,, uint256 shortfall) = comptrollerProxy.getAccountLiquidity(taker);
        assertGt(shortfall, 0);

        uint256 repayAmount = cUSDC.borrowBalanceStored(taker) / 2;

        bytes memory data = abi.encode(cUSDC, cUNI, taker);
        FlashLoanLiquidation liquidation = new FlashLoanLiquidation();
        liquidation.flashLoanAndLiquidate(_USDC, repayAmount, data);
        liquidation.claim();
        vm.stopPrank();

        // check 
        assertGe(usdc.balanceOf(liquidator), 63 * 1e6);
    }
}

interface IPool {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ISwapRouter.ExactInputSingleParams memory params) external returns (uint256 amountOut);
}

contract FlashLoanLiquidation {
    address _USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address _UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    ERC20 usdc = ERC20(_USDC);
    ERC20 uni = ERC20(_UNI);

    IPool pool = IPool(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    ISwapRouter swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    address immutable _owner;

    constructor() {
        _owner = msg.sender;
    }

    function flashLoanAndLiquidate(
        address token, 
        uint256 amount, 
        bytes calldata params
    ) public {
        pool.flashLoanSimple(address(this), token, amount, params, 0);
    }

    function executeOperation(
        address asset, 
        uint256 amount, 
        uint256 premium, 
        address initiator, 
        bytes calldata params
    ) external returns (bool) {
        require(initiator == address(this));
        require(msg.sender == address(pool));

        (CErc20Delegator cUSDC, CErc20Delegator cUNI, address user) =
            abi.decode(params, (CErc20Delegator, CErc20Delegator, address));

        usdc.approve(address(cUSDC), type(uint256).max);
        cUSDC.liquidateBorrow(user, amount, cUNI);
        cUNI.redeem(cUNI.balanceOf(address(this)));

        uni.approve(address(swapRouter), type(uint256).max);
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter.ExactInputSingleParams({
            tokenIn: _UNI,
            tokenOut: _USDC,
            fee: 3000, // 0.3%
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: uni.balanceOf(address(this)),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });
        swapRouter.exactInputSingle(swapParams);

        uint256 amountOwed = amount + premium;
        ERC20(asset).approve(address(pool), amountOwed);

        return true;
    }

    function claim() public {
        usdc.transfer(_owner, usdc.balanceOf(address(this)));
    }
}