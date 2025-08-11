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

    bytes32 public constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(address pair,address sender,address tokenIn,uint256 amountIn,uint256 nonce)");

    mapping(address => uint256) private _nonces;

    constructor() EIP712(EIP712_DOMAIN, EIP712_VERSION) {}

    function getDomainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function getNonce(address _sender) public view returns (uint256) {
        return _nonces[_sender];
    }

    function verify(SwapEIP712 memory _swapParams, bytes memory _signature) public view returns (bool) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    _swapParams.pair,
                    _swapParams.sender,
                    _swapParams.tokenIn,
                    _swapParams.amountIn,
                    _swapParams.nonce
                )
            )
        );
        address signer = digest.recover(_signature);
        return signer == _swapParams.sender;
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
        ISwapSwopPair(_swapParams.pair).swap(_swapParams.sender, _swapParams.tokenIn, _swapParams.amountIn);

        return true;
    }
}
