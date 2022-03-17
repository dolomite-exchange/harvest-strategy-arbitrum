This is where implementations of `IDolomiteAssetTransformer.sol` will go. Implementations of this interface are 
responsible for mapping assets of a particular asset type into its fToken counterpart or reverting fTokens into their
underlying components. This file simplifies the needs of depositors to make (leveraged) yield farming easy.

Once DolomiteMargin is enabled for Harvest Arbitrum, users that want to engage in "spot" yield farming (that is, yield
farming without any leverage) should be migrated to use the `IDolomiteAssetTransformer` paradigm as a simplification
of the current deposit flow.
