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
        tokenA.freeMint(mintAmount);
        tokenA.approve(address(cTokenA), mintAmount);
        cTokenA.mint(mintAmount);
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
        tokenA.approve(address(cTokenA), 50 * 10 ** tokenDecimals);
        cTokenA.repayBorrow(50 * 10 ** tokenDecimals);
        vm.stopPrank();

        assertEq(tokenA.balanceOf(user1), 0);
    }


    function _user1Borrow() private {
        vm.startPrank(user1);
        tokenB.freeMint(mintAmount);
        tokenB.approve(address(cTokenB), mintAmount);
        cTokenB.mint(mintAmount);
        assertEq(cTokenB.balanceOf(user1), mintAmount);

        address[] memory cTokens = new address[](1);
        cTokens[0] = address(cTokenB);
        comptrollerProxy.enterMarkets(cTokens);
        cTokenA.borrow(50 * 10 ** tokenDecimals);
        assertEq(tokenA.balanceOf(user1), 50 * 10 ** tokenDecimals);
        vm.stopPrank();
    }
}
