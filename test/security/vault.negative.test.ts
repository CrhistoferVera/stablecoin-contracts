import { expect } from "chai";
import { deploySystem, getEthers } from "../helpers/fixture.js";

describe("Vault/Token - negative & security tests", function () {
  it("Token: decimals() debe ser 6", async () => {
    const { coin } = await deploySystem();
    expect(await coin.decimals()).to.equal(6);
  });

  it("Token: mint() debe revertir si NO lo llama el vault", async () => {
    const { coin, owner } = await deploySystem();
    await expect(coin.connect(owner).mint(owner.address, 1n))
      .to.be.revertedWith("Only vault can mint");
  });

  it("Token: burnFromVault() debe revertir si NO lo llama el vault", async () => {
    const { coin, owner } = await deploySystem();
    await expect(coin.connect(owner).burnFromVault(owner.address, 1n))
      .to.be.revertedWith("Only vault can burn");
  });

  it("Vault: mintStable debe revertir si NO hay allowance", async () => {
    const ethers = await getEthers();
    const { owner, collateral, vault } = await deploySystem();

    const depositAmount = 150n * 1_000_000n;
    await (await collateral.mint(owner.address, depositAmount)).wait();

    // no approve -> transferFrom falla (puede ser custom error o revert)
    await expect(vault.connect(owner).mintStable(depositAmount)).to.revert(ethers);
  });

  it("Vault: mintStable debe revertir si NO hay balance de colateral", async () => {
    const ethers = await getEthers();
    const { owner, vault } = await deploySystem();

    const depositAmount = 150n * 1_000_000n;
    // sin balance -> transferFrom falla
    await expect(vault.connect(owner).mintStable(depositAmount)).to.revert(ethers);
  });

  it("Vault: redeemStable debe revertir si el usuario no tiene BOBH suficiente", async () => {
    const ethers = await getEthers();
    const { owner, vault } = await deploySystem();

    // no tiene stablecoin -> burn revertirá
    await expect(vault.connect(owner).redeemStable(1n)).to.revert(ethers);
  });

  it("Vault: redeemStable debe revertir si el usuario intenta retirar más colateral del depositado (underflow)", async () => {
    const ethers = await getEthers();
    const { owner, coin, collateral, vault } = await deploySystem();

    // Deposita y mintea algo pequeño
    const depositAmount = 150n * 1_000_000n;
    await (await collateral.mint(owner.address, depositAmount)).wait();
    await (await collateral.approve(vault.target, depositAmount)).wait();
    await (await vault.mintStable(depositAmount)).wait();

    // Intenta redimir TODO el minted + extra para provocar underflow en depositedCollateral -= collateralReturn
    // (el extra puede hacer que collateralReturn sea mayor que lo depositado)
    const minted = await coin.balanceOf(owner.address);
    await expect(vault.connect(owner).redeemStable(minted + 1n)).to.revert(ethers);
  });

  it("⚠️ Riesgo de deployment: si alguien setea vault antes, el deploy del Vault revierte", async () => {
    const ethers = await getEthers();
    const [owner, attacker] = await ethers.getSigners();

    const coin = await ethers.deployContract("MyStableCoin");
    await coin.waitForDeployment();

    const collateral = await ethers.deployContract("ERC20Mock", ["USDC Test", "USDC", 6]);
    await collateral.waitForDeployment();

    // atacante fija vault primero (porque setVault no tiene control de acceso)
    await (await coin.connect(attacker).setVault(attacker.address)).wait();

    // al desplegar el Vault, el constructor llama setVault(address(this)) -> revierte "Vault already set"
    await expect(
      ethers.deployContract("StableCoinVault", [coin.target, collateral.target])
    ).to.be.revertedWith("Vault already set");
  });
});
