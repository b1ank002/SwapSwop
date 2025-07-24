// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./interfaces/ISwapSwopPair.sol";
import "./SwapSwopLp.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LSwapSwopPair} from "./libraries/LSwapSwopPair.sol";

contract SwapSwopPair is ISwapSwopPair {
    address public token0;
    address public token1;

    LpToken public lpToken;

    uint256 public reserve0;
    uint256 public reserve1;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;

        lpToken = new LpToken(address(this));
    }

    function addLiquidity(uint256 _amount0, uint256 _amount1) public {
        if (_amount0 == 0) revert InsufficientLiquidityToken0();
        if (_amount1 == 0) revert InsufficientLiquidityToken1();

        if (!LSwapSwopPair.isValidLiquidityRatio(reserve0, reserve1, _amount0, _amount1)) {
            revert InvalidLiquidityRatio();
        }

        require(IERC20(token0).transferFrom(msg.sender, address(this), _amount0), TransferFailed());
        require(IERC20(token1).transferFrom(msg.sender, address(this), _amount1), TransferFailed());

        reserve0 += _amount0;
        reserve1 += _amount1;

        uint256 amountLpToken =
            LSwapSwopPair.getAmountLpToken(_amount0, _amount1, reserve0, reserve1, lpToken.totalSupply());
        lpToken.mint(msg.sender, amountLpToken);

        emit AddLiquidity(msg.sender, _amount0, _amount1, amountLpToken);
    }

    function removeLiquidity(uint256 _amountLpToken) public {
        if (_amountLpToken > lpToken.balanceOf(msg.sender)) revert InsufficientLiquidityLpToken();

        (uint256 amount0, uint256 amount1) =
            LSwapSwopPair.getAmountToken0andToken1(_amountLpToken, reserve0, reserve1, lpToken.totalSupply());

        reserve0 -= amount0;
        reserve1 -= amount1;

        lpToken.burnFrom(msg.sender, _amountLpToken);

        require(IERC20(token0).transfer(msg.sender, amount0), TransferFailed());
        require(IERC20(token1).transfer(msg.sender, amount1), TransferFailed());

        emit RemoveLiquidity(msg.sender, amount0, amount1, _amountLpToken);
    }

    function swap(address _tokenIn, uint256 _amountIn) public {
        if (_tokenIn != token0 && _tokenIn != token1) revert InvalidTokenAddress();
        if (_amountIn == 0) revert InvalidAmount();
        if (reserve0 == 0 || reserve1 == 0) revert InsufficientLiquidity();
        if (_amountIn > IERC20(_tokenIn).balanceOf(msg.sender)) revert InsufficientBalance();

        _tokenIn = _tokenIn == token0 ? token0 : token1;
        address tokenOut = _tokenIn == token0 ? token1 : token0;
        uint256 reserveIn = _tokenIn == token0 ? reserve0 : reserve1;
        uint256 reserveOut = _tokenIn == token0 ? reserve0 : reserve1;

        require(IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn), TransferFailed());

        uint256 amountOut = LSwapSwopPair.getAmountOut(_amountIn, reserveIn, reserveOut);
        if (amountOut > reserveOut) revert InsufficientLiquidityTokenOut();

        require(IERC20(tokenOut).transfer(msg.sender, amountOut), TransferFailed());

        reserveIn += _amountIn;
        reserveOut -= amountOut;

        emit Swap(msg.sender, _tokenIn, _amountIn, tokenOut, amountOut);
    }
}
