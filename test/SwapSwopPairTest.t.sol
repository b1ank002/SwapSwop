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
import {SwapSwopEIP712} from "../src/SwapSwopEIP712.sol";

contract SwapSwopPairTest is Test {
    SwapSwopPair public swapSwopPair;

    MockToken0 public token0;
    MockToken1 public token1;

    LpToken public lpToken;

    SwapSwopEIP712 public eip712Swap;

    uint256 constant AMOUNT_TOKEN0 = 100_000 * 1e6; // usdt
    uint256 constant AMOUNT_TOKEN1 = 100 * 1e18; // eth

    function setUp() public {
        token0 = new MockToken0(address(this), AMOUNT_TOKEN0);
        token1 = new MockToken1(address(this), AMOUNT_TOKEN1);

        eip712Swap = new SwapSwopEIP712();

        swapSwopPair = new SwapSwopPair(address(token0), address(token1), address(eip712Swap));

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

        uint256 amountLpToken = LSwapSwopPair.getAmountLpToken(_amount0, _amount1, 0, 0, lpToken.totalSupply());
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
        vm.assume(
            LSwapSwopPair.isValidLiquidityRatio(swapSwopPair.reserve0(), swapSwopPair.reserve1(), _amount0, _amount1)
                == false
        );

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

        (uint256 amount0, uint256 amount1) = LSwapSwopPair.getAmountToken0andToken1(
            _amountLpToken, swapSwopPair.reserve0(), swapSwopPair.reserve1(), lpToken.totalSupply()
        );

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

    function test_Remove_Liquidity_InsufficientLiquidityLpToken(
        uint256 _amount0,
        uint256 _amount1,
        uint256 _amountLpToken
    ) public {
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

        (uint256 amount0, uint256 amount1) = LSwapSwopPair.getAmountToken0andToken1(
            _amountLpToken, swapSwopPair.reserve0(), swapSwopPair.reserve1(), lpToken.totalSupply()
        );

        vm.mockCall(
            address(token0), abi.encodeWithSelector(IERC20.transfer.selector, address(this), amount0), abi.encode(false)
        );

        vm.expectRevert(ISwapSwopPair.TransferFailed.selector);
        swapSwopPair.removeLiquidity(_amountLpToken);

        vm.mockCall(
            address(token1), abi.encodeWithSelector(IERC20.transfer.selector, address(this), amount1), abi.encode(false)
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
        vm.assume(amountOut > 0);
        IERC20(tokenIn).approve(address(swapSwopPair), _amountIn);

        vm.expectEmit(true, true, true, true);
        emit ISwapSwopPair.Swap(address(this), tokenIn, _amountIn, tokenOut, amountOut);
        swapSwopPair.swap(msg.sender, tokenIn, _amountIn);

        assertEq(lpToken.totalSupply(), amountLpToken);
        if (_isToken0) {
            assertEq(swapSwopPair.reserve0(), reserveIn + _amountIn);
            assertEq(swapSwopPair.reserve1(), reserveOut - amountOut);
        } else {
            assertEq(swapSwopPair.reserve0(), reserveOut - amountOut);
            assertEq(swapSwopPair.reserve1(), reserveIn + _amountIn);
        }
    }

    function test_Swap_Revert_InvalidTokenAddress(
        uint256 _amount0,
        uint256 _amount1,
        address _tokenIn,
        uint256 _amountIn
    ) public {
        vm.assume(_amount0 > 0 && _amount1 > 0);
        vm.assume(_amount0 <= AMOUNT_TOKEN0 && _amount1 <= AMOUNT_TOKEN1);

        uint256 amountLpToken = test_Add_Liquidity_Success(_amount0, _amount1);

        vm.assume(_tokenIn != address(token0) && _tokenIn != address(token1));

        vm.expectRevert(ISwapSwopPair.InvalidTokenAddress.selector);
        swapSwopPair.swap(msg.sender, _tokenIn, _amountIn);

        vm.expectRevert(ISwapSwopPair.InvalidTokenAddress.selector);
        swapSwopPair.swap(msg.sender, address(0), _amountIn);

        assertEq(lpToken.totalSupply(), amountLpToken);
        assertEq(swapSwopPair.reserve0(), _amount0);
        assertEq(swapSwopPair.reserve1(), _amount1);
        assertEq(token0.balanceOf(address(swapSwopPair)), _amount0);
        assertEq(token1.balanceOf(address(swapSwopPair)), _amount1);
    }

    function test_Swap_Revert_InvalidAmount(uint256 _amount0, uint256 _amount1, bool _isToken0) public {
        vm.assume(_amount0 > 0 && _amount1 > 0);
        vm.assume(_amount0 <= AMOUNT_TOKEN0 && _amount1 <= AMOUNT_TOKEN1);

        uint256 amountLpToken = test_Add_Liquidity_Success(_amount0, _amount1);

        if (_isToken0) {
            vm.expectRevert(ISwapSwopPair.InvalidAmount.selector);
            swapSwopPair.swap(msg.sender, address(token0), 0);
        } else {
            vm.expectRevert(ISwapSwopPair.InvalidAmount.selector);
            swapSwopPair.swap(msg.sender, address(token1), 0);
        }

        assertEq(lpToken.totalSupply(), amountLpToken);
        assertEq(swapSwopPair.reserve0(), _amount0);
        assertEq(swapSwopPair.reserve1(), _amount1);
        assertEq(token0.balanceOf(address(swapSwopPair)), _amount0);
        assertEq(token1.balanceOf(address(swapSwopPair)), _amount1);
    }

    function test_Swap_Revert_InsufficientLiquidity(bool _isToken0, uint256 _amountIn) public {
        vm.assume(_amountIn > 0);

        if (_isToken0) {
            vm.expectRevert(ISwapSwopPair.InsufficientLiquidity.selector);
            swapSwopPair.swap(msg.sender, address(token0), _amountIn);
        } else {
            vm.expectRevert(ISwapSwopPair.InsufficientLiquidity.selector);
            swapSwopPair.swap(msg.sender, address(token1), _amountIn);
        }

        assertEq(lpToken.totalSupply(), 0);
        assertEq(swapSwopPair.reserve0(), 0);
        assertEq(swapSwopPair.reserve1(), 0);
        assertEq(token0.balanceOf(address(swapSwopPair)), 0);
        assertEq(token1.balanceOf(address(swapSwopPair)), 0);
    }

    function test_Swap_Revert_InsufficientBalance(uint256 _amount0, uint256 _amount1, bool _isToken0, uint256 _amountIn)
        public
    {
        vm.assume(_amount0 > 0 && _amount1 > 0);
        vm.assume(_amount0 <= AMOUNT_TOKEN0 && _amount1 <= AMOUNT_TOKEN1);

        uint256 amountLpToken = test_Add_Liquidity_Success(_amount0, _amount1);

        if (_isToken0) {
            vm.assume(_amountIn > token0.balanceOf(address(this)));

            vm.expectRevert(ISwapSwopPair.InsufficientBalance.selector);
            swapSwopPair.swap(msg.sender, address(token0), _amountIn);
        } else {
            vm.assume(_amountIn > token1.balanceOf(address(this)));

            vm.expectRevert(ISwapSwopPair.InsufficientBalance.selector);
            swapSwopPair.swap(msg.sender, address(token1), _amountIn);
        }

        assertEq(lpToken.totalSupply(), amountLpToken);
        assertEq(swapSwopPair.reserve0(), _amount0);
        assertEq(swapSwopPair.reserve1(), _amount1);
        assertEq(token0.balanceOf(address(swapSwopPair)), _amount0);
        assertEq(token1.balanceOf(address(swapSwopPair)), _amount1);
    }

    function test_Swap_Revert_InvalidOutputAmount(uint256 _amount0, uint256 _amount1, bool _isToken0, uint256 _amountIn)
        public
    {
        vm.assume(_amount0 > 0 && _amount1 > 0);
        vm.assume(_amount0 <= AMOUNT_TOKEN0 && _amount1 <= AMOUNT_TOKEN1);

        token0.approve(address(swapSwopPair), _amount0);
        token1.approve(address(swapSwopPair), _amount1);
        swapSwopPair.addLiquidity(_amount0, _amount1);

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
        vm.assume(amountOut < 1);

        IERC20(tokenIn).approve(address(swapSwopPair), _amountIn);

        vm.expectRevert(ISwapSwopPair.InvalidOutputAmount.selector);
        swapSwopPair.swap(msg.sender, tokenIn, _amountIn);

        assertEq(swapSwopPair.reserve0(), _amount0);
        assertEq(swapSwopPair.reserve1(), _amount1);
        assertEq(token0.balanceOf(address(swapSwopPair)), _amount0);
        assertEq(token1.balanceOf(address(swapSwopPair)), _amount1);
    }

    function test_Swap_Revert_TransferFailed(uint256 _amount0, uint256 _amount1, bool _isToken0, uint256 _amountIn)
        public
    {
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
        IERC20(tokenIn).approve(address(swapSwopPair), _amountIn);

        vm.mockCall(
            address(tokenIn),
            abi.encodeWithSelector(IERC20.transferFrom.selector, address(this), address(swapSwopPair), _amountIn),
            abi.encode(false)
        );

        vm.expectRevert(ISwapSwopPair.TransferFailed.selector);
        swapSwopPair.swap(msg.sender, tokenIn, _amountIn);

        vm.mockCall(
            address(tokenOut),
            abi.encodeWithSelector(IERC20.transfer.selector, address(this), amountOut),
            abi.encode(false)
        );

        vm.expectRevert(ISwapSwopPair.TransferFailed.selector);
        swapSwopPair.swap(msg.sender, tokenIn, _amountIn);

        assertEq(lpToken.totalSupply(), amountLpToken);
        assertEq(swapSwopPair.reserve0(), _amount0);
        assertEq(swapSwopPair.reserve1(), _amount1);
        assertEq(token0.balanceOf(address(swapSwopPair)), _amount0);
        assertEq(token1.balanceOf(address(swapSwopPair)), _amount1);
    }
}
