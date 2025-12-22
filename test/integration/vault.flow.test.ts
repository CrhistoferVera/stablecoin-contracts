import { expect } from "chai";
import { deploySystem } from "../helpers/fixture.js";

describe("Vault Flow - integration", function () {
  it("constructor: Vault queda seteado en MyStableCoin", async () => {
    const { coin, vault } = await deploySystem();
    expect(await coin.vault()).to.equal(vault.target);
  });

  it("mintStable: deposita colateral y mintea BOBH (150% => 150 USDC -> 100 BOBH)", async () => {
    const { owner, coin, collateral, vault } = await deploySystem();

    const depositAmount = 150n * 1_000_000n; // 150 USDC (6 decimales)

    await (await collateral.mint(owner.address, depositAmount)).wait();
    await (await collateral.approve(vault.target, depositAmount)).wait();
    await (await vault.mintStable(depositAmount)).wait();

    // ✅ expected con fórmula correcta: mint = deposit * 100 / 150 = 100 USDC-equivalente
    const expectedMint = depositAmount * 100n / 150n; // = 100 * 1e6
    expect(await coin.balanceOf(owner.address)).to.equal(expectedMint);

    // el vault guarda el colateral
    expect(await collateral.balanceOf(vault.target)).to.equal(depositAmount);
    expect(await vault.depositedCollateral(owner.address)).to.equal(depositAmount);
  });

  it("redeemStable: quema BOBH y devuelve colateral proporcional", async () => {
    const { owner, coin, collateral, vault } = await deploySystem();

    const depositAmount = 150n * 1_000_000n;
    await (await collateral.mint(owner.address, depositAmount)).wait();
    await (await collateral.approve(vault.target, depositAmount)).wait();
    await (await vault.mintStable(depositAmount)).wait();

    // Quemar 50 BOBH (en unidades 6 decimales)
    const burnAmount = 50n * 1_000_000n;
    const collateralReturn = burnAmount * 150n / 100n; // 75 USDC (6 decimales)

    const ownerCollateralBefore = await collateral.balanceOf(owner.address);

    await (await vault.redeemStable(burnAmount)).wait();

    expect(await collateral.balanceOf(owner.address)).to.equal(ownerCollateralBefore + collateralReturn);
    expect(await vault.depositedCollateral(owner.address)).to.equal(depositAmount - collateralReturn);
  });
});
