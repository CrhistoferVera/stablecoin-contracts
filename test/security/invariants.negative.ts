import { expect } from "chai";
import { deploySystem } from "../helpers/fixture.js";

describe("Vault invariants", function () {
  it("Vault collateral balance debe ser >= suma depositada (para users del test)", async () => {
    const { owner, user1, collateral, vault } = await deploySystem();

    const depOwner = 150n * 1_000_000n;
    const depUser1 = 300n * 1_000_000n;

    await (await collateral.mint(owner.address, depOwner)).wait();
    await (await collateral.mint(user1.address, depUser1)).wait();

    await (await collateral.connect(owner).approve(vault.target, depOwner)).wait();
    await (await collateral.connect(user1).approve(vault.target, depUser1)).wait();

    await (await vault.connect(owner).mintStable(depOwner)).wait();
    await (await vault.connect(user1).mintStable(depUser1)).wait();

    const sumDeposited =
      (await vault.depositedCollateral(owner.address)) +
      (await vault.depositedCollateral(user1.address));

    const vaultBal = await collateral.balanceOf(vault.target);
    expect(vaultBal).to.equal(sumDeposited);
  });
});
