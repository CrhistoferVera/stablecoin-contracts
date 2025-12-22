import { expect } from "chai";
import { network } from "hardhat";
const { ethers } = await network.connect();

describe("Token - basic behavior", function () {
    async function deployFixture() {
        const [owner, user1, user2] = await ethers.getSigners();

        const Token = await ethers.getContractFactory("MyStableCoin");
        const token = await Token.deploy();
        await token.waitForDeployment();
        return { token, owner, user1, user2 };
    }

    it("should have correct decimals", async function () {
        const { token } = await deployFixture();
        expect(await token.decimals()).to.equal(6);
    });

    it("should start with zero total supply", async function () {
        const { token } = await deployFixture();
        expect(await token.totalSupply()).to.equal(0);
    });
});
