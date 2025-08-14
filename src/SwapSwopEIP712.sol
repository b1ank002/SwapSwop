// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ISwapSwopEIP712} from "./interfaces/ISwapSwopEIP712.sol";
import {ISwapSwopPair} from "./interfaces/ISwapSwopPair.sol";

contract SwapSwopEIP712 is EIP712, ISwapSwopEIP712 {
    using ECDSA for bytes32;

    string public constant EIP712_DOMAIN = "SwapSwopEIP712";
    string public constant EIP712_VERSION = "1";

    bytes32 public constant SWAP_TYPEHASH = keccak256(
        "SwapEIP712(address pair,address sender,address tokenIn,uint256 amountIn,uint256 minAmountOut,uint256 nonce,uint256 deadline)"
    );

    mapping(address => uint256) private _nonces;

    constructor() EIP712(EIP712_DOMAIN, EIP712_VERSION) {}

    function getNonce(address _sender) public view returns (uint256) {
        return _nonces[_sender];
    }

    function verify(SwapEIP712 memory _swapParams, bytes memory _signature) public view returns (bool) {
        bytes32 digest = _hashSwap(_swapParams);

        address signer = digest.recover(_signature);
        return signer == _swapParams.sender;
    }

    function _hashSwap(ISwapSwopEIP712.SwapEIP712 memory _swapParams) public view returns (bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(
                SWAP_TYPEHASH,
                _swapParams.pair,
                _swapParams.sender,
                _swapParams.tokenIn,
                _swapParams.amountIn,
                _swapParams.minAmountOut,
                _swapParams.nonce,
                _swapParams.deadline
            )
        );

        return _hashTypedDataV4(structHash);
    }

    /// @notice Get the domain separator for EIP-712 typed data signing
    /// @return The domain separator hash
    /// @dev This is used to ensure signatures are unique to this contract and domain
    function getDomainSeperator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function executeSwap(SwapEIP712 memory _swapParams, bytes memory _signature) public returns (bool) {
        if (!verify(_swapParams, _signature)) {
            revert InvalideSignature();
        }

        if (block.timestamp > _swapParams.deadline) {
            revert DeadlineExpired();
        }

        if (_swapParams.nonce != _nonces[_swapParams.sender]) {
            revert InvalideNonce();
        }

        _nonces[_swapParams.sender]++;

        uint256 actualAmount =
            ISwapSwopPair(_swapParams.pair).swap(_swapParams.sender, _swapParams.tokenIn, _swapParams.amountIn);
        require(
            actualAmount > _swapParams.minAmountOut, InsufficientOutputAmount(actualAmount, _swapParams.minAmountOut)
        );

        emit SwapExecuted(_swapParams.pair, _swapParams.sender, _swapParams.tokenIn, _swapParams.amountIn, actualAmount);

        return true;
    }
}
