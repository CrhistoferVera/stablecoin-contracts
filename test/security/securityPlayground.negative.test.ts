import { get } from "http";
import { deployContract, getEthers } from "../helpers/deploy.js";
import { TARGET_CONTRACT } from "../helpers/targets.js";
import { expect } from "chai";



describe("SecurityPlayground - negative/security tests", function () {
  async function deploy() {
    const ethers = await getEthers();
    const [admin, minter, user, attacker] = await ethers.getSigners();

    // fijo: siempre despliega SecurityPlayground
    const { contract: playground } = await deployContract("SecurityPlayground", [admin.address]);

    const MINTER_ROLE = await playground.MINTER_ROLE();
    const PAUSER_ROLE = await playground.PAUSER_ROLE();
    const DEFAULT_ADMIN_ROLE = await playground.DEFAULT_ADMIN_ROLE();

    return {
      ethers,
      playground,
      admin,
      minter,
      user,
      attacker,
      MINTER_ROLE,
      PAUSER_ROLE,
      DEFAULT_ADMIN_ROLE,
    };
  }

  it("should revert mint() if caller lacks MINTER_ROLE", async () => {
    const { playground, attacker, user, MINTER_ROLE } = await deploy();

    await expect(playground.connect(attacker).mint(user.address, 1n))
      .to.be.revertedWithCustomError(playground, "AccessControlUnauthorizedAccount")
      .withArgs(attacker.address, MINTER_ROLE);
  });

  it("should revert mint() to zero address", async () => {
    const { playground, admin, ethers } = await deploy();

    await expect(playground.connect(admin).mint(ethers.ZeroAddress, 1n)).to.be
      .revertedWith("ZERO_ADDRESS");
  });

  it("should revert mint() with zero amount", async () => {
    const { playground, admin, user } = await deploy();

    await expect(playground.connect(admin).mint(user.address, 0n)).to.be
      .revertedWith("ZERO_AMOUNT");
  });

  it("should revert mint() if recipient is blacklisted", async () => {
    const { playground, admin, user } = await deploy();

    await playground.connect(admin).setBlacklisted(user.address, true);

    await expect(playground.connect(admin).mint(user.address, 1n)).to.be
      .revertedWith("BLACKLISTED");
  });

  it("should revert pause() if caller lacks PAUSER_ROLE", async () => {
    const { playground, attacker, PAUSER_ROLE } = await deploy();

    await expect(playground.connect(attacker).pause())
      .to.be.revertedWithCustomError(playground, "AccessControlUnauthorizedAccount")
      .withArgs(attacker.address, PAUSER_ROLE);
  });

  it("should revert unpause() if caller lacks PAUSER_ROLE", async () => {
    const { playground, admin, attacker, PAUSER_ROLE } = await deploy();

    // primero pausamos con admin para poder probar unpause
    await playground.connect(admin).pause();

    await expect(playground.connect(attacker).unpause())
      .to.be.revertedWithCustomError(playground, "AccessControlUnauthorizedAccount")
      .withArgs(attacker.address, PAUSER_ROLE);
  });

  it("should revert mint() when paused", async () => {
    const { playground, admin, user, ethers } = await deploy();

    await playground.connect(admin).pause();

    await expect(
      playground.connect(admin).mint(user.address, 1n)
    ).to.revert(ethers);
  });

  it("should not allow non-admin to set blacklist", async () => {
    const { playground, attacker, user, DEFAULT_ADMIN_ROLE } = await deploy();

    await expect(playground.connect(attacker).setBlacklisted(user.address, true))
      .to.be.revertedWithCustomError(playground, "AccessControlUnauthorizedAccount")
      .withArgs(attacker.address, DEFAULT_ADMIN_ROLE);
  });
});
