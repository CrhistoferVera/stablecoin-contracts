import { expect } from "chai";
import { network } from "hardhat";
const { ethers } = await network.connect();


describe("Mint and transfer (happy path)", function () {
    async function deployFixture() {
        const [owner, user1] = await ethers.getSigners();

        const Token = await ethers.getContractFactory("MyStablecoin");
        const token = await Token.deploy();
        await token.waitForDeployment();

        return { token, owner, user1 };
    }

    it("should mint tokens and update balance", async function () {
        const { token, owner, user1 } = await deployFixture();

        const amount = 1_000_000; // 1 token (6 decimals)

        await token.mint(user1.address, amount);

        expect(await token.balanceOf(user1.address)).to.equal(amount);
        expect(await token.totalSupply()).to.equal(amount);
    });

    it("should transfer tokens correctly", async function () {
        const { token, owner, user1 } = await deployFixture();

        const amount = 1_000_000;

        await token.mint(owner.address, amount);
        await token.transfer(user1.address, amount);

        expect(await token.balanceOf(user1.address)).to.equal(amount);
        expect(await token.balanceOf(owner.address)).to.equal(0);
    });
});
