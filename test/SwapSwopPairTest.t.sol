// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {SwapSwopPair} from "../src/SwapSwopPair.sol";
import {ISwapSwopPair} from "../src/interfaces/ISwapSwopPair.sol";
import {LSwapSwopPair} from "../src/libraries/LSwapSwopPair.sol";
import {LpToken} from "../src/SwapSwopLp.sol";
import {MockToken0} from "./testTokens/MockToken0.sol";
import {MockToken1} from "./testTokens/MockToken1.sol";

contract SwapSwopPairTest is Test {
    SwapSwopPair public swapSwopPair;

    MockToken0 public token0;
    MockToken1 public token1;

    LpToken public lpToken;

    uint256 constant AMOUNT_TOKEN0 = 100_000 * 1e6; // usdt
    uint256 constant AMOUNT_TOKEN1 = 100 * 1e18; // eth

    function setUp() public {
        token0 = new MockToken0(address(this), AMOUNT_TOKEN0);
        token1 = new MockToken1(address(this), AMOUNT_TOKEN1);

        swapSwopPair = new SwapSwopPair(address(token0), address(token1));

        lpToken = swapSwopPair.lpToken();
    }

    function test_Initial_State() public view {
        assertEq(swapSwopPair.token0(), address(token0));
        assertEq(swapSwopPair.token1(), address(token1));

        assertEq(lpToken.totalSupply(), 0);

        assertEq(swapSwopPair.reserve0(), 0);
        assertEq(swapSwopPair.reserve1(), 0);
    }

    function test_Add_Liquidity_ForcedValues_Success(uint256 _amount0, uint256 _amount1) public {
        vm.assume(_amount0 > 0 && _amount1 > 0);
        vm.assume(_amount0 <= AMOUNT_TOKEN0 && _amount1 <= AMOUNT_TOKEN1);

         uint256 amountLpToken =
            LSwapSwopPair.getAmountLpToken(_amount0, _amount1, 0, 0, lpToken.totalSupply());
        console.log("amountLpToken: ", amountLpToken);

        token0.approve(address(swapSwopPair), _amount0);
        token1.approve(address(swapSwopPair), _amount1);

        vm.expectEmit(true, false, false, true);
        emit ISwapSwopPair.AddLiquidity(address(this), _amount0, _amount1, amountLpToken);
        swapSwopPair.addLiquidity(_amount0, _amount1);

        assertEq(swapSwopPair.reserve0(), _amount0);
        assertEq(swapSwopPair.reserve1(), _amount1);
        assertEq(lpToken.balanceOf(address(this)), amountLpToken);
        assertEq(token0.balanceOf(address(swapSwopPair)), _amount0);
        assertEq(token1.balanceOf(address(swapSwopPair)), _amount1);
    }

    function test_Add_Liquidity_Success() public {
        uint256 amountLpToken =
            LSwapSwopPair.getAmountLpToken(5000, 5, 0, 0, lpToken.totalSupply());
        console.log("amountLpToken: ", amountLpToken);

        token0.approve(address(swapSwopPair), 5000);
        token1.approve(address(swapSwopPair), 5);

        vm.expectEmit(true, false, false, true);
        emit ISwapSwopPair.AddLiquidity(address(this), 5000, 5, amountLpToken);
        swapSwopPair.addLiquidity(5000, 5);

        assertEq(swapSwopPair.reserve0(), 5000);
        assertEq(swapSwopPair.reserve1(), 5);
        assertEq(lpToken.balanceOf(address(this)), amountLpToken);
        assertEq(token0.balanceOf(address(swapSwopPair)), 5000);
        assertEq(token1.balanceOf(address(swapSwopPair)), 5);
    }
}