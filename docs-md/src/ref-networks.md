


# {#ref-networks} Consensus Network Connectors

This section describes the consensus network connectors
supported by Reach version ${VERSION}.

${toc}

## {#ref-network-algo} Algorand

The [Algorand](https://www.algorand.com/) Reach connector generates a set of
contracts that manage one instance of the DApp's
execution.

It uses finite on-chain state.
The DApp consists of one application and one contract-controlled escrow account.

It relies on versions of `algod` that support TEAL version 4, such as Algorand 2.7.1 from July 2021.
It uses the Algorand `indexer` version 2 to lookup and monitor publications; in other words, it does _not_ rely on any communication network other than Algorand itself.

Algorand uses the SHA256 algorithm to perform digests.
Its bit width is 64-bits.

Non-network tokens are compiled to [Algorand Standard Assets](https://developer.algorand.org/docs/features/asa/) (ASAs).
Specifically, the `Token` type refers to the id of the ASA.

Token minting creates an ASA owned and managed by the contract account.
Freezing, clawback, reserves, and separate managers are not supported.

Algorand's ASAs have some inherent design flaws that inhibit reasoning about them.
First, the "freezing" "feature" disables the ability of contracts (and users) from transfering their assets, without prior notification that the asset is frozen (i.e., in one moment, a contract may transfer an asset, but then in the next moment, without any change to the contract state, it ceases to be able to transfer it, because elsewhere in the network, an asset was frozen.)
Second, the "clawback" "feature" extracts assets from an account without approval by or notification of the account holder.
Third, the "opt-in" "feature" prevents accounts from transfering assets without prior approval by the receiver.
Fourth, the "opt-out" "feature" allows accounts to take-back the permission to transfer assets to them after having previously given it.
Each of these issues mean that rely-guarantee reasoning is not appropriate for analyzing consensus steps on Algorand: in other words, it is not possible to guarantee from the structure of a program that consensus steps which are dominated by honest interactions will succeed, because external agents can arbitrarily change the semantics of consensus operations.
This essentially amounts to all Algorand DApps that use non-network tokens being inherently vulnerable to denial-of-service attacks when these "features" are used.
For example, if a DApp has a consensus step where Alice will receive 1 gil and Bob will receive 2 zorkmids, either Alice or Bob can prevent this step from executing by opting out of (respectively) gil or zorkmids.
(An "opt-out" is performed by sending an [Asset Transfer Transaction](https://developer.algorand.org/docs/reference/transactions/#asset-transfer-transaction) (`axfer`) with a non-zero `AssetCloseTo` field.)
You can alleviate this problem by ensuring that any non-network token transfers occur as the last consensus steps of the program and may be executed in any order by the recipient of the funds.
Similarly, if a DApp accepts a non-network token that has enabled clawback, then it can be prevented from progressing if the manager takes the contract's tokens behind its back.
Unfortunately, there is no way to alleviate this, other than refusing to accept tokens that have the possibility of clawback, but on Algorand, tokens default to allowing clawback, so that is not feasible.
Rather than simplying rejecting all programs that use non-network tokens on Algorand, Reach allows them, with these caveats about the reliability of the generated contracts.
We hope that future versions of Algorand will provide a facility for preventing these attacks, such as by removing these "features".

Views are compiled to client-side functions that can interpret the global and local state of the Algorand Application associated with the DApp.
This means they are sensitive to the particular compilation details of the particular Reach program.
We hope to work with the Algorand community to define a standard for views.
Views expand the on-chain state to include the free variables of all values bound to a view.

Linear state is compiled into Application Local State.
This means that participants must explicitly "opt-in" to storing this state on their account (which increases their minimum balance).
The Reach standard library will do this automatically when connecting to Reach generated contracts, but other users must be specifically programmed to do this.
This "opt-in" requirement means that DApps with linear state deployed on Algorand can deadlock and be held hostage:
Suppose that Alice transfers 10 ALGO to a contract in step one, then in step two, the consensus must store a value associated with Bob, and then she can receive her 10 ALGO back, then the program terminates.
On some networks, Alice can perform these two steps completely on her own and she is in complete control of her funds.
However, on Algorand, running this program requires that Bob "opt-in" to storing values for the application.
We hope that future versions of Algorand will allow other parties to pay the fees to "opt-in" to applications to prevent these kinds of deadlock attacks.

In Algorand, network time corresponds to round numbers and network seconds correspond to the Unix timestamp of the previous round.
(This is because the current round's timestamp is not determined until after it is finalized.
This means that a network second-based deadline could be exceeded by the round time of the network, which is typically five seconds.)

The connector provides a binding named `ALGO` to
backends.

Backends must respect the following environment variables:

+ `ALGO_TOKEN` is used as the API token for your `algod`.
+ `ALGO_SERVER` is used as the address of your `algod`.
+ `ALGO_PORT` is used as the port of your `algod`.
+ `ALGO_INDEXER_TOKEN` is used as the API token for your `indexer`.
+ `ALGO_INDEXER_SERVER` is used as the address of your `indexer`.
+ `ALGO_INDEXER_PORT` is used as the port of your `indexer`.
+ `ALGO_FAUCET_PASSPHRASE` is used as the mnemonic for the faucet of your network.
This is useful if you are running your own testing network.


## {#ref-network-cfx} Conflux

The [Conflux](https://confluxnetwork.org/) Reach connector works almost identically to the [Ethereum connector](##ref-network-eth), except that it behaves differently at runtime: using, for example, [Conflux Portal](https://portal.confluxnetwork.org/) rather than [MetaMask](https://metamask.io/), and connecting to Conflux nodes.

Backends must respect the following environment variables:

+ `CFX_NODE_URI` is used to contact the Conflux node.
It defaults to `http://localhost:12537`.
+ `CFX_NETWORK_ID` is used to determine the Conflux network id.
It defaults to `999`.


### {#cfx-faq} FAQ

#### {#cfx-faq-mainnet} How do I run my Reach DApp on CFX TestNet or MainNet?

You can add the following JavaScript near the beginning of your index.js or index.mjs file
in order to run on Conflux TestNet:

```js
reach.setProviderByName('TestNet');
```


Or this to run on Conflux MainNet:

```js
reach.setProviderByName('MainNet');
```


It is strongly recommended that you also use `setQueryLowerBound`
to avoid waiting for unnecessary queries.
For example, this code snippet sets the lower bound at 2000 blocks ago:

```js
const now = await reach.getNetworkTime();
reach.setQueryLowerBound(reach.sub(now, 2000));
```


#### {#cfx-faq-query} Why is DApp startup very slow? Why do I need to use `setQueryLowerBound`?

DApp startup doesn't have to be slow.
Reach relies on querying Conflux event logs in order to run the DApp.
The Conflux network does not yet provide fast APIs for querying event logs for a given contract across all time,
so instead, Reach incrementally queries across chunks of 1000 blocks at a time.
You can use `setQueryLowerBound` to help Reach know at what block number to start querying,
so that it does not have to start querying at the beginning of time, which can take quite a while.

#### {#cfx-faq-cplocal} How can I use ConfluxPortal with the Reach devnet?

If you find that ConfluxPortal's Localhost 12537 default configuration does not work correctly with Reach apps,
you can try configuring ConfluxPortal to use a custom RPC endpoint:

+ Click the network dropdown in Conflux Portal
+ Select: Custom RPC
+ Use RPC url: http://127.0.0.1:12537


If your locally-running Conflux devnet restarts,
you may find that you need to reset ConfluxPortal's account history,
which you can do like so:

+ Select the desired account
+ Click the profile image of the account (top-right)
+ Click Settings > Advanced > Reset Account > (confirm) Reset
+ Switch to a different network and back
+ CTRL+SHIFT+R to hard-reset the webpage.


## {#ref-network-eth} Ethereum

The [Ethereum](https://ethereum.org/) Reach connector generates a contract that
manages one instance of the DApp's execution.
It is guaranteed to
use exactly one word of on-chain state, while each piece of consensus state appears as a transaction argument.

Ethereum uses the Keccak256 algorithm to perform digests.
Its bit width is 256-bits.

Non-network tokens are compiled to [ERC-20](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/) fungible tokens.
Specifically, the `Token` type refers to the address of the ERC-20 contract.
Token minting launches a fresh ERC-20 contract based on the OpenZeppelin ERC-20 implementation, which stores additional metadata and allows the creator to burn tokens and destroy the token if there is no supply (i.e. it has all been burned).

Views are compiled to `view` functions.
A view named `X.Y` will be named `X_Y`.
Views expand the on-chain state to include the free variables of all values bound to a view.

In Ethereum, network time corresponds to block numbers and network seconds correspond to the Unix timestamp of the block.

The connector provides a binding named `ETH` to
backends.

During compilation, the connector produces one intermediate output: `input.export.sol`, containing
the Solidity code implementing the contract.

A few details of Ethereum leak through to Reach.
The node that a given participant is connected to does not instantly know that its blocks are correct and may revert past transactions after it reaches consensus with the rest of the network.
This means that Reach applications must not make externally observable effects until after such consensus is reached.

Backends must respect the following environment variables:

+ `ETH_NODE_URI` is used to contact the Ethereum node.
It defaults to `http://localhost:8545`.
+ `ETH_NODE_NETWORK` is used to name the Ethereum network.
It defaults to `unspecified`.
