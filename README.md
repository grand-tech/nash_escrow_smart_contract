# Nash Escrow Smart Contract.
This project contain smart contracts that cater for P2P top up
and withdrawal transactions using asymetric comment encryption
to obfuscate payment information on CELO blockchain. 
The smart contract has been designed to work with any ECR20 token
on any EVM based chain.


## Hardhat commands. 

```shell
npx hardhat compile
npx hardhat clean
npx hardhat test
```

## Celoscan verification.

To try out Etherscan verification, you first need to deploy a contract to an Ethereum network that's supported by Etherscan, such as Ropsten.

In this project, copy the .env.example file to a file named .env, and then edit it to fill in the details. Enter your Etherscan API key, your Ropsten node URL (eg from Alchemy), and the private key of the account which will send the deployment transaction. With a valid .env file in place, first deploy your contract:

```shell
npx hardhat run --network alfajores scripts/deploy_testnet.ts
```

Then, copy the deployment address and paste it in to replace `DEPLOYED_CONTRACT_ADDRESS` in this command:

```shell
npx hardhat verify --network alfajores DEPLOYED_CONTRACT_ADDRESS
```

## Creating upgradable smart contracts that are ownable.

https://forum.openzeppelin.com/t/how-to-use-ownable-with-upgradeable-contract/3336



## Auditing.

Using mythril.
```
source mythril-env/bin/activate;

 clear; myth analyze contracts/NashEscrow.sol --solc-json solc.json

```


Using Cyfrin Aderyn.
https://www.cyfrin.io/blog/find-vulnerabilities-in-your-solidity-codebase-using-cyfrin-aderyn
```
aderyn
```

Using slither
```
slither .
```


## Front end integration with typescript.
Breaks down some of the steps taken to integrate the smart 
contract with a typescript based front end.

### Transaction data types.

```typescript
/**
 * Transaction types.
 */
export enum TransactionType {
  DEPOSIT = 'DEPOSIT',

  WITHDRAWAL = 'WITHDRAWAL',
}

/**
 * Status types.
 */
export enum Status {
  AWAITING_AGENT,

  AWAITING_CONFIRMATIONS,

  CONFIRMED,

  CANCELED,

  DONE,
}

/**
 * @typedef {Object} NashEscrowTransaction Nash escrow transaction object.
 * @property { number } id - the transaction id.
 * @property { TransactionType } txType - the transaction type.
 * @property { string } clientAddress - clientAddress the clients address.
 * @property { Status } status - the status of the transaction.
 * @property { number } amount - the amount of money being sent in the transaction.
 * @property { string } agentAddress - the agents address.
 * @property { boolean } agentApproval - true on agents approval.
 * @property { boolean } clientApproval - true on clients approval.
 * @property { string } clientPaymentDetails - the client`s phone number.
 * @property { string } agentPaymentDetails - the agent`s phone number.
 * @property { string } exchangeToken the echange token address.
 * @property { string } exchangeTokenLabel the exchange token lable.
 */
export type NashEscrowTransaction = {
  id: number;
  txType: TransactionType;
  clientAddress: string;
  agentAddress: string;
  status: number;
  amount: number;
  agentApproval: string;
  clientApproval: string;
  agentPaymentDetails: string;
  clientPaymentDetails: string;
  exchangeToken: string;
  exchangeTokenLabel: string;
};


/**
* Generates nash transaction object (typescript) from data queried from
* the smart contract.
* @param tx the response object.
* @returns the nash transaction object.
*/
export function convertToNashTransactionObj(tx: string[]): NashEscrowTransaction {
    let txType = TransactionType.DEPOSIT;

    if (parseInt(tx[1], 10) === 1) {
        txType = TransactionType.WITHDRAWAL;
    }

    const nashTx: NashEscrowTransaction = {
        id: parseInt(tx[0], 10),
        txType: txType,
        clientAddress: tx[2],
        agentAddress: tx[3],
        status: parseInt(tx[4], 10),
        amount: Number(kit?.web3.utils.fromWei(tx[5], 'ether')),
        agentApproval: tx[6],
        clientApproval: tx[7],
        agentPaymentDetails: tx[8],
        clientPaymentDetails: tx[9],
        exchangeToken: tx[10],
        exchangeTokenLabel: tx[11],
    };
    return nashTx;
}


```

### Comment encryption utils.
An array of functions that power the comment encryption feature used to obfuscate payment information..

```typescript

import {
  CommentEncryptionUtils,
  EncryptionStatus,
} from '@celo/cryptographic-utils';
import {hexToBuffer} from '@celo/utils/lib/address';

/**
 * Comments saved by the agent or client on the escrow transaction.
 * @typedef {Record<string, string>} EscrowTxComment properties crypto account.
 * @property { string} mpesaNumber the m-pesa phone number.
 * @property { string } payBill the m-pesa paybill number.
 * @property { string } accountNumber the m-pesa account number.
 * @property { string } paymentName the name expected to be seen after the payment is done off chain.
 */
export interface EscrowTxComment extends Record<string, string> {
  mpesaNumber: string;
  payBill: string;
  accountNumber: string;
  paymentName: string;
}

/**
 * Used to mark segments within comment.
 */
export const COMMENT_SEPARATOR = '*#*';

/**
 * Separates a key from its value in the comment.
 */
export const KEY_VALUE_SEPARATOR = ':#:';

/**
 * Encrypts escrow transactions comment.
 * @param escrowTxComment data to be encrypted.
 * @param sendersDEK the senders data encryption key.
 * @param receiversDEK the receivers data encryption key.
 * @returns data encryption status.
 */
export function encryptEscrowTXComment(
  escrowTxComment: EscrowTxComment,
  sendersDEK: string,
  receiversDEK: string,
) {
  const comment = constructEscrowCommentString(escrowTxComment);
  return nashEncryptComment(sendersDEK, receiversDEK, comment);
}

/**
 * Encrypts a comment.
 * @param sendersDEK senders data encryption key.
 * @param receiversDEK receivers data encryption key.
 * @param comment the comment to be encrypted.
 * @returns the encryption process result.
 */
export function nashEncryptComment(
  sendersDEK: string,
  receiversDEK: string,
  comment: string,
): EncryptionStatus {
  const rDEK = hexToBuffer(receiversDEK);
  const sDEK = hexToBuffer(sendersDEK);
  return CommentEncryptionUtils.encryptComment(comment, rDEK, sDEK);
}

/**
 * Constructs a comment from the values in the escrow tx comment obj.
 * @param escrowTxComment the comment to be encrypted.
 * @returns the constructed comment.
 */
export function constructEscrowCommentString(
  escrowTxComment: EscrowTxComment,
): string {
  let comment: string = '';

  const keyPairs = Object.entries(escrowTxComment);

  for (let index = 0; index < keyPairs.length; index++) {
    const key = keyPairs[index][0];
    const value = keyPairs[index][1].trim();
    if (value && value !== '') {
      const keyVal = key + KEY_VALUE_SEPARATOR + value;
      if (comment === '') {
        comment = keyVal;
      } else {
        comment = comment + COMMENT_SEPARATOR + keyVal;
      }
    }
  }

  return comment;
}

/**
 * Constructs a comment from the values in the escrow tx comment obj.
 * @param escrowTxComment the comment to be encrypted.
 * @returns the constructed comment.
 */
export function constructEscrowCommentObject(
  escrowTxComment: string,
): EscrowTxComment {
  let comment: string[] = escrowTxComment.split(COMMENT_SEPARATOR);

  const commentObj: EscrowTxComment = {
    mpesaNumber: '',
    payBill: '',
    accountNumber: '',
    paymentName: '',
  };

  const keys = Object.keys(commentObj);
  for (const commentSection in comment) {
    const keyValue = comment[commentSection].split(KEY_VALUE_SEPARATOR);

    if (keys.includes(keyValue[0])) {
      commentObj[keyValue[0]] = keyValue[1];
    }
  }

  return commentObj;
}

/**
 * Decrypts an encrypted comment.
 * @param comment the encrypted comment.
 * @param privateKey the private key use to decrypt the cypher text.
 * @param isSender if the private key belongs to the sender.
 * @returns status of the decryption process with the plain text.
 */
export function nashDecryptComment(
  comment: string,
  privateKey: string,
  isSender: boolean,
): EncryptionStatus {
  const key = hexToBuffer(privateKey);
  return CommentEncryptionUtils.decryptComment(comment, key, isSender);
}

```
