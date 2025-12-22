import { expect } from "chai";
import { getEthers, deployTarget } from "../helpers/deploy.js";
import { TARGET_CONTRACT } from "../helpers/targets.js";

before(function () {
  if (TARGET_CONTRACT !== "MyStableCoin") this.skip();
});

describe("MyStableCoin - negative/security tests", function () {
  async function setup() {
    const ethers = await getEthers();
    const [admin, attacker, user] = await ethers.getSigners();

    const { contract: token } = await deployTarget(); // apunta a TARGET_CONTRACT
    return { ethers, token, admin, attacker, user };
  }

  it("decimals() debe ser 6", async () => {
    const { token } = await setup();
    expect(await token.decimals()).to.equal(6);
  });

  it("mint() debe revertir si NO lo llama el vault", async () => {
    const { token, admin, user } = await setup();

    // vault está en 0x0 al inicio, así que nadie debería poder mintear
    await expect(token.connect(admin).mint(user.address, 1n))
      .to.be.revertedWith("Only vault can mint");
  });

  it("burnFromVault() debe revertir si NO lo llama el vault", async () => {
    const { token, admin, user } = await setup();

    await expect(token.connect(admin).burnFromVault(user.address, 1n))
      .to.be.revertedWith("Only vault can burn");
  });

  it("setVault() solo se puede ejecutar una vez", async () => {
    const { token, admin } = await setup();

    await token.connect(admin).setVault(admin.address);

    await expect(token.connect(admin).setVault(admin.address))
      .to.be.revertedWith("Vault already set");
  });

  it("⚠️ VULNERABILIDAD: cualquiera puede setear el vault la primera vez", async () => {
    const { token, attacker, user } = await setup();

    // Un atacante fija el vault a sí mismo
    // setVault
    const tx1 = await token.connect(attacker).setVault(attacker.address);
    await tx1.wait();
    // Ahora el atacante puede mintear libremente
    // mint
    const tx2 = await token.connect(attacker).mint(user.address, 1_000_000n);
    await tx2.wait();

    expect(await token.balanceOf(user.address)).to.equal(1_000_000n);
  });
});
