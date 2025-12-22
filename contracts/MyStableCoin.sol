// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MyStableCoin is ERC20, ERC20Burnable {
    //Define el nombre ys imbolo de la moneda
    constructor() ERC20("HUNBOLI", "BOBH") {}

    // USDT-style decimals(1 token = 1,000,000 unidades internas. Ejemplo: 
    //Si un usuario tiene 2.5 BOBH: internamente es 2.5 * 10^6 = 2,500,000 unidades.)
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // Mint y burn serán llamados solo por el Vault(crea tokens y los asigna a to Ejemplo: 
    //Usuario deposita 150 USDC en el Vault. Vault llama mint(user, 100) → usuario recibe 100 BOBH.totalSupply aumenta 100 BOBH. )
    function mint(address to, uint256 amount) external {
        require(msg.sender == vault, "Only vault can mint");
        _mint(to, amount);
    }

    function burnFromVault(address from, uint256 amount) external {
        require(msg.sender == vault, "Only vault can burn");
        _burn(from, amount);
    }

    // Dirección del contrato que controla mint/burnVariable que almacena la dirección del Vault.
    //El Vault es el único que puede crear o quemar tokens.
    //public → cualquiera puede leer la dirección.
    address public vault;

    //Después de desplegar MyStableCoin, llamas setVault(addressDelVault).
    //Ahora solo addressDelVault puede mint/burn.
    function setVault(address _vault) external {
        require(vault == address(0), "Vault already set");
        vault = _vault;
    }
}
