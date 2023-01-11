import { ethers, upgrades } from "hardhat";

// TODO: pluck out some code from environment variables.

const PROXY = "0xD0A96C8D738Ad3019D26499D8956F032056296ef";

async function main() {
  const NashEscrow = await ethers.getContractFactory("NashEscrow");
  const nashEscrow = await upgrades.upgradeProxy(PROXY, NashEscrow);

  await nashEscrow.deployed();
  console.log("NashEscrow upgrade to: { ", nashEscrow.address, " } ");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});