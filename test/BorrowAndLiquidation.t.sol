// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "test/CompoundSetUp.sol";

contract BorrowAndLiquidationTest is Test, CompoundSetUp {

    address admin = makeAddr("admin");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    
    function setUp() public {
        vm.startPrank(admin);
        deployCompound();
        vm.stopPrank();
    }

    function test_MintAndRedeem() public {
        uint256 mintAmount = 100 * 10 ** tokenA.decimals();

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
}
