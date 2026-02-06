// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @dev Wrapper para que Hardhat genere el artifact de ERC1967Proxy.
 * Este contrato no agrega lógica, solo hace disponible ERC1967Proxy para deploy scripts.
 */
contract MyStableCoinProxy is ERC1967Proxy {
    constructor(
        address implementation,
        bytes memory _data
    ) ERC1967Proxy(implementation, _data) {}
}
