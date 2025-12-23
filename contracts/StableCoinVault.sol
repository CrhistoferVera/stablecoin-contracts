// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./MyStableCoin.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StableCoinVault {

    MyStableCoin public stableCoin;//token (HUNBOLI/BOBH).
    IERC20 public collateralToken; // el token que respalda la stablecoin, p.ej., USDC.
    uint256 public collateralization = 150; //porcentaje de garantía que respalda cada token emitido.150% significa que si quieres 100 BOBH, debes depositar 150 USDC.

    //Lleva el registro de cuánto colateral ha depositado cada usuario.
    //Ejemplo: Alice deposita 150 USDC → depositedCollateral[Alice] = 150
    mapping(address => uint256) public depositedCollateral;

    //Inicializa los contratos:stableCoin = HUNBOLI/BOBH
    //collateralToken = USDC
    //Asigna Vault al token, para que solo este contrato pueda mint/burn.
    constructor(address _stableCoin, address _collateralToken) {
        stableCoin = MyStableCoin(_stableCoin);
        collateralToken = IERC20(_collateralToken);
        stableCoin.setVault(address(this));
    }

    // Depositar colateral y recibir tokens. collateralAmount=cantidad que deposita el usuario
    //Ejemplo real:
    //Alice deposita 150 USDC, colateralización = 150%
    //Mint calculado: 150 * 1_000_000 / 150 * 100 = 100_000_000 → 100 BOBH
    //Alice recibe 100 BOBH y Vault guarda 150 USDC
    function mintStable(uint256 collateralAmount) external {
        uint256 mintAmount = collateralAmount * 100 / collateralization;
        require(collateralToken.transferFrom(msg.sender, address(this), collateralAmount), "Transfer failed");
        depositedCollateral[msg.sender] += collateralAmount;
        stableCoin.mint(msg.sender, mintAmount);
    }

    // Quemar tokens y recuperar colateral.
    //Alice quema 50 BOBH
    //Recibe 75 USDC de vuelta
    //Vault sigue guardando el resto del colateral
    function redeemStable(uint256 tokenAmount) external {
        uint256 collateralReturn = tokenAmount * collateralization / 100;
        stableCoin.burnFromVault(msg.sender, tokenAmount);
        depositedCollateral[msg.sender] -= collateralReturn;
        require(collateralToken.transfer(msg.sender, collateralReturn), "Transfer failed");
    }
}
