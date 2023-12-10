// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "test/CompoundSetUp.sol";

contract BorrowAndLiquidationTest is Test, CompoundSetUp {

    address admin = makeAddr("admin");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address maker = makeAddr("maker");
    uint tokenDecimals = 18;
    uint256 mintAmount = 100 * 10 ** tokenDecimals;

    function setUp() public {
        vm.startPrank(admin);
        deployCompound();
        vm.stopPrank();

        vm.startPrank(maker);
        tokenA.freeMint(10000 * mintAmount);
        tokenA.approve(address(cTokenA), 10000 * mintAmount);
        cTokenA.mint(10000 * mintAmount);
        vm.stopPrank();
    }

    function test_MintAndRedeem() public {
        vm.startPrank(user1);
        // mint tokenA
        tokenA.freeMint(mintAmount);
        assertEq(tokenA.balanceOf(user1), mintAmount);
        // mint cTokenA
        tokenA.approve(address(cTokenA), mintAmount);
        cTokenA.mint(mintAmount);
        assertEq(cTokenA.balanceOf(user1), mintAmount);
        assertEq(tokenA.balanceOf(user1), 0);
        // redeem tokenA with cTokenA
        cTokenA.redeem(mintAmount);
        assertEq(cTokenA.balanceOf(user1), 0);
        assertEq(tokenA.balanceOf(user1), mintAmount);
        vm.stopPrank();
    }

    function test_BorrowAndRepay() public {
        _user1Borrow();
        vm.startPrank(user1);
        tokenA.approve(address(cTokenA), 50 * mintAmount);
        cTokenA.repayBorrow(50 * mintAmount);
        vm.stopPrank();

        assertEq(tokenA.balanceOf(user1), 0);
    }

    function test_CollateralFactorAndLiquidation() public {
        _user1Borrow();

        vm.startPrank(admin);
        comptrollerProxy._setCollateralFactor(CToken(address(cTokenB)), 1e17);
        vm.stopPrank();

        vm.startPrank(user2);
        tokenA.freeMint(50 * mintAmount);
        tokenA.approve(address(cTokenA), 50 * mintAmount);

         (,, uint256 shortfall) = comptrollerProxy.getAccountLiquidity(user1);
        assertGt(shortfall, 0);

        uint256 borrowBalance = cTokenA.borrowBalanceStored(user1);
        cTokenA.liquidateBorrow(user1, (borrowBalance / 2), cTokenB);
        assertEq(
            tokenA.balanceOf(user2), 
            (50 * mintAmount) - (borrowBalance / 2)
        );

        (, uint256 seizeTokens) = comptrollerProxy.liquidateCalculateSeizeTokens(
            address(cTokenA), 
            address(cTokenB), 
            (borrowBalance / 2)
        );
        assertEq(
            cTokenB.balanceOf(user2), 
            seizeTokens * (1e18 - cTokenA.protocolSeizeShareMantissa()) / 1e18
        );
        vm.stopPrank();

    }
    
    // function test_PriceChangeAndLiquidation() public {

    // }

    function _user1Borrow() private {
        vm.startPrank(user1);
        tokenB.freeMint(mintAmount); 
        tokenB.approve(address(cTokenB), mintAmount);
        cTokenB.mint(mintAmount);
        assertEq(cTokenB.balanceOf(user1), mintAmount);

        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cTokenB);
        comptrollerProxy.enterMarkets(cTokens);
        cTokenA.borrow(50 * mintAmount); // 50 = price(100) * collateralFactor(0.5)
        assertEq(tokenA.balanceOf(user1), 50 * mintAmount);
        vm.stopPrank();
    }
}
