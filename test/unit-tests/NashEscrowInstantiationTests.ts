import { expect } from "chai";
import { TestUtil } from "../testutils";

describe("Test withdrawal transaction end to end.", function () {
  it("Test", async function () {
    const testUtil = new TestUtil();
    await testUtil.intit();

    await testUtil.cUSD.approve(testUtil.nashEscrow.address, 10);

    expect(await testUtil.nashEscrow.getNextTransactionIndex()).to.equal(0);

    expect(
      await testUtil.nashEscrow.initializeWithdrawalTransaction(
        5,
        "test phone number"
      )
    )
      .to.emit("NashEscrow", "TransactionInitEvent")
      .withArgs(0, testUtil.user1Address.getAddress());

    expect(await testUtil.nashEscrow.getNextTransactionIndex()).to.equal(1);
  });
});
