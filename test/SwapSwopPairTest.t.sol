// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {SwapSwopPair} from "../src/SwapSwopPair.sol";
import {ISwapSwopPair} from "../src/interfaces/ISwapSwopPair.sol";
import {LSwapSwopPair} from "../src/libraries/LSwapSwopPair.sol";
import {LpToken} from "../src/SwapSwopLp.sol";
import {MockToken0} from "./testTokens/MockToken0.sol";
import {MockToken1} from "./testTokens/MockToken1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

    function test_Add_Liquidity_Success(uint256 _amount0, uint256 _amount1) public returns (uint256) {
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

        return amountLpToken;
    }

    function test_Add_Liquidity_InsufficientLiquidityToken0(uint256 _amount) public {
        vm.expectRevert(ISwapSwopPair.InsufficientLiquidityToken0.selector);
        swapSwopPair.addLiquidity(0, _amount);

        vm.expectRevert(ISwapSwopPair.InsufficientLiquidityToken0.selector);
        swapSwopPair.addLiquidity(0, 0);

        assertEq(swapSwopPair.reserve0(), 0);
        assertEq(swapSwopPair.reserve1(), 0);
        assertEq(lpToken.balanceOf(address(this)), 0);
    }

    function test_Add_Liquidity_InsufficientLiquidityToken1(uint256 _amount) public {
        vm.assume(_amount > 0);

        vm.expectRevert(ISwapSwopPair.InsufficientLiquidityToken1.selector);
        swapSwopPair.addLiquidity(_amount, 0);

        assertEq(swapSwopPair.reserve0(), 0);
        assertEq(swapSwopPair.reserve1(), 0);
        assertEq(lpToken.balanceOf(address(this)), 0);
    }

    function test_Add_Liquidity_InvalidLiquidityRatio(uint256 _amount0, uint256 _amount1) public {
        uint256 amountLpToken = test_Add_Liquidity_Success(5000, 5);

        vm.assume(_amount0 > 0 && _amount1 > 0);
        vm.assume(_amount0 <= AMOUNT_TOKEN0 - 5000 && _amount1 <= AMOUNT_TOKEN1 - 5);
        vm.assume(LSwapSwopPair.isValidLiquidityRatio(swapSwopPair.reserve0(), swapSwopPair.reserve1(), _amount0, _amount1) == false);

        token0.approve(address(swapSwopPair), _amount0);
        token1.approve(address(swapSwopPair), _amount1);

        vm.expectRevert(ISwapSwopPair.InvalidLiquidityRatio.selector);
        swapSwopPair.addLiquidity(_amount0, _amount1);

        vm.expectRevert(ISwapSwopPair.InvalidLiquidityRatio.selector);
        swapSwopPair.addLiquidity(_amount1, _amount0);

        assertEq(swapSwopPair.reserve0(), 5000);
        assertEq(swapSwopPair.reserve1(), 5);
        assertEq(lpToken.balanceOf(address(this)), amountLpToken);
    }

    function test_Add_Liquidity_TransferFailed(uint256 _amount0, uint256 _amount1) public {
        vm.assume(_amount0 > 0 && _amount1 > 0);
        vm.assume(_amount0 <= AMOUNT_TOKEN0 && _amount1 <= AMOUNT_TOKEN1);

        vm.mockCall(
            address(token0),
            abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(swapSwopPair), _amount0),
            abi.encode(false)
        );

        vm.expectRevert(ISwapSwopPair.TransferFailed.selector);
        swapSwopPair.addLiquidity(_amount0, _amount1);

        vm.mockCall(
            address(token1),
            abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(swapSwopPair), _amount1),
            abi.encode(false)
        );

        vm.expectRevert(ISwapSwopPair.TransferFailed.selector);
        swapSwopPair.addLiquidity(_amount0, _amount1);

        assertEq(swapSwopPair.reserve0(), 0);
        assertEq(swapSwopPair.reserve1(), 0);
        assertEq(lpToken.balanceOf(address(this)), 0);
    }

    function test_Remove_Liquidity_Success(uint256 _amount0, uint256 _amount1, uint256 _amountLpToken) public {
        vm.assume(_amount0 > 0 && _amount1 > 0);
        vm.assume(_amount0 <= AMOUNT_TOKEN0 && _amount1 <= AMOUNT_TOKEN1);

        uint256 amountLpToken = test_Add_Liquidity_Success(_amount0, _amount1);

        vm.assume(_amountLpToken > 0 && _amountLpToken <= amountLpToken);

        (uint256 amount0, uint256 amount1) =
            LSwapSwopPair.getAmountToken0andToken1(_amountLpToken, swapSwopPair.reserve0(), swapSwopPair.reserve1(), lpToken.totalSupply());

        lpToken.approve(address(swapSwopPair), _amountLpToken);

        vm.expectEmit(true, false, false, true);
        emit ISwapSwopPair.RemoveLiquidity(address(this), amount0, amount1, _amountLpToken);
        swapSwopPair.removeLiquidity(_amountLpToken);

        assertEq(swapSwopPair.reserve0(), _amount0 - amount0);
        assertEq(swapSwopPair.reserve1(), _amount1 - amount1);
        assertEq(lpToken.balanceOf(address(this)), amountLpToken - _amountLpToken);
        assertEq(token0.balanceOf(address(swapSwopPair)), _amount0 - amount0);
        assertEq(token1.balanceOf(address(swapSwopPair)), _amount1 - amount1);
        assertEq(lpToken.totalSupply(), amountLpToken - _amountLpToken);
    }

    function test_Remove_Liquidity_InsufficientLiquidityLpToken(uint256 _amount0, uint256 _amount1, uint256 _amountLpToken) public {
        vm.assume(_amount0 > 0 && _amount1 > 0);
        vm.assume(_amount0 <= AMOUNT_TOKEN0 && _amount1 <= AMOUNT_TOKEN1);

        uint256 amountLpToken = test_Add_Liquidity_Success(_amount0, _amount1);
        vm.assume(_amountLpToken > amountLpToken);

        vm.expectRevert(ISwapSwopPair.InsufficientLiquidityLpToken.selector);
        swapSwopPair.removeLiquidity(_amountLpToken);

        assertEq(swapSwopPair.reserve0(), _amount0);
        assertEq(swapSwopPair.reserve1(), _amount1);
        assertEq(lpToken.balanceOf(address(this)), amountLpToken);
        assertEq(token0.balanceOf(address(swapSwopPair)), _amount0);
        assertEq(token1.balanceOf(address(swapSwopPair)), _amount1);
    }

    function test_Remove_Liquidity_TransferFailed(uint256 _amount0, uint256 _amount1, uint256 _amountLpToken) public {
        vm.assume(_amount0 > 0 && _amount1 > 0);
        vm.assume(_amount0 <= AMOUNT_TOKEN0 && _amount1 <= AMOUNT_TOKEN1);

        uint256 amountLpToken = test_Add_Liquidity_Success(_amount0, _amount1);
        vm.assume(_amountLpToken > 0 && _amountLpToken <= amountLpToken);

        lpToken.approve(address(swapSwopPair), _amountLpToken);

        (uint256 amount0, uint256 amount1) =
            LSwapSwopPair.getAmountToken0andToken1(_amountLpToken, swapSwopPair.reserve0(), swapSwopPair.reserve1(), lpToken.totalSupply());

        vm.mockCall(
            address(token0),
            abi.encodeWithSelector(IERC20.transfer.selector, address(this), amount0),
            abi.encode(false)
        );

        vm.expectRevert(ISwapSwopPair.TransferFailed.selector);
        swapSwopPair.removeLiquidity(_amountLpToken);

        vm.mockCall(
            address(token1),
            abi.encodeWithSelector(IERC20.transfer.selector, address(this), amount1),
            abi.encode(false)
        );

        vm.expectRevert(ISwapSwopPair.TransferFailed.selector);
        swapSwopPair.removeLiquidity(_amountLpToken);

        assertEq(swapSwopPair.reserve0(), _amount0);
        assertEq(swapSwopPair.reserve1(), _amount1);
        assertEq(lpToken.balanceOf(address(this)), amountLpToken);
        assertEq(token0.balanceOf(address(swapSwopPair)), _amount0);
        assertEq(token1.balanceOf(address(swapSwopPair)), _amount1);
    }

    function test_Swap_Success(uint256 _amount0, uint256 _amount1, bool _isToken0, uint256 _amountIn) public {
        vm.assume(_amount0 > 0 && _amount1 > 0);
        vm.assume(_amount0 <= AMOUNT_TOKEN0 && _amount1 <= AMOUNT_TOKEN1);

        uint256 amountLpToken = test_Add_Liquidity_Success(_amount0, _amount1);

        address tokenIn;
        address tokenOut;
        uint256 reserveIn;
        uint256 reserveOut;

        vm.assume(_amountIn > 0);
        if (_isToken0) {
            vm.assume(_amountIn <= swapSwopPair.reserve0());
            vm.assume(_amountIn <= token0.balanceOf(address(this)));

            tokenIn = address(token0);
            tokenOut = address(token1);
            reserveIn = swapSwopPair.reserve0();
            reserveOut = swapSwopPair.reserve1();
        } else {
            vm.assume(_amountIn <= swapSwopPair.reserve1());
            vm.assume(_amountIn <= token1.balanceOf(address(this)));

            tokenIn = address(token1);
            tokenOut = address(token0);
            reserveIn = swapSwopPair.reserve1();
            reserveOut = swapSwopPair.reserve0();
        }

        uint256 amountOut = LSwapSwopPair.getAmountOut(_amountIn, reserveIn, reserveOut);
        console.log("amountOut: ", amountOut);
        console.log("reserveOut: ", reserveOut);
        console.log("balanceOf tokenOut: ", IERC20(tokenOut).balanceOf(address(swapSwopPair)));

        IERC20(tokenIn).approve(address(swapSwopPair), _amountIn);
        deal(tokenOut, address(swapSwopPair), 1000000000000000000);
        console.log("new balanceOf tokenOut: ", IERC20(tokenOut).balanceOf(address(swapSwopPair)));

        vm.expectEmit(true, true, true, false);
        emit ISwapSwopPair.Swap(address(this), tokenIn, _amountIn, tokenOut, amountOut);
        swapSwopPair.swap(tokenIn, _amountIn);
        console.log("final balanceOf tokenOut: ", IERC20(tokenOut).balanceOf(address(swapSwopPair)));

        assertEq(lpToken.totalSupply(), amountLpToken);
    }
}