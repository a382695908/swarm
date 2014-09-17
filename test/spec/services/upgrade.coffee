'use strict'

describe 'Service: upgradetype', ->

  # load the service's module
  beforeEach module 'swarmApp'

  # instantiate service
  upgradetypes = {}
  beforeEach inject (_upgradetypes_) ->
    upgradetypes = _upgradetypes_

  it 'should parse the spreadsheet', ->
    expect(!!upgradetypes).toBe true
    expect(!!upgradetypes.list).toBe true
    expect(upgradetypes.list.length).toBeGreaterThan 4

describe 'Service: upgrade', ->

  # load the service's module
  beforeEach module 'swarmApp'

  # instantiate service
  Game = {}
  unittypes = {}
  beforeEach inject (_Game_, _unittypes_) ->
    Game = _Game_
    unittypes = _unittypes_
  mkgame = (unittypes, reified=new Date 0) ->
    game = new Game {unittypes: unittypes, upgrades:{}, date:{reified:reified}, save:->}
    game.now = new Date 0
    return game

  # TODO why is this of all things disconnecting the test
  # ...because units have a cycle, and jasmine loops forever trying to print test failures with a cycle. D'oh.
  it 'buys upgrades', ->
    game = mkgame {territory:999999999}
    expect(upgrade = game.upgrade 'expansion').toBe game.unit('invisiblehatchery').upgrades.byName['expansion']
    expect(upgrade.count()).toBe 0
    upgrade.buy()
    expect(upgrade.count()).toBe 1

  it 'blocks expensive upgrades', ->
    game = mkgame {territory:1}
    upgrade = game.upgrade 'expansion'
    expect(upgrade.count()).toBe 0
    expect(-> upgrade.buy()).toThrow()
    expect(upgrade.count()).toBe 0

  it 'calcs upgrade stats, no unit', ->
    game = mkgame {drone:99999999999999}
    upgrade = game.upgrade 'droneprod'
    upgrade2 = game.upgrade 'queenprod'
    stats = {}
    schema = {}
    upgrade.stats(stats, schema)
    expect(stats.prod).toBe 1
    stats2 = {}
    upgrade2.stats(stats2, schema)
    expect(stats2.prod).toBe 1

    upgrade.buy()
    stats = {}
    upgrade.stats(stats, schema)
    expect(stats.prod).toBeGreaterThan 1
    stats2 = {}
    upgrade2.stats(stats2, schema)
    expect(stats2.prod).toBe 1

  it 'buys/calcs max upgrades', ->
    game = mkgame {territory:99}
    upgrade = game.upgrade 'expansion'
    expect(upgrade.maxCostMet()).toBe 0
    game.unit('territory')._setCount 100
    expect(upgrade.maxCostMet()).toBe 1
    game.unit('territory')._setCount 250
    expect(upgrade.maxCostMet()).toBe 2
    game.unit('territory')._setCount 1000
    expect(upgrade.maxCostMet()).toBe 5
    upgrade.buyMax()
    expect(upgrade.maxCostMet()).toBe 0
    expect(upgrade.count()).toBe 5

  it 'injects larvae', ->
    game = mkgame {energy:9999999999999999999, larva:1000}
    upgrade = game.upgrade 'clonelarvae'
    unit = game.unit 'larva'
    upgrade.buy 3
    expect(upgrade.count()).toBe 3
    expect(unit.count()).toBe 8000

  it 'buy more than max', ->
    game = mkgame {territory:100}
    upgrade = game.upgrade 'expansion'
    expect(upgrade.maxCostMet()).toBe 1
    expect(upgrade.count()).toBe 0
    upgrade.buy 10
    expect(upgrade.maxCostMet()).toBe 0
    expect(upgrade.count()).toBe 1

  it 'clones cocoons', ->
    game = mkgame {energy:1000000000000000000000000000000000000000, cocoon: 100, larva: 10}
    cocoon = game.unit 'cocoon'
    larva = game.unit 'larva'
    inject = game.upgrade 'clonelarvae'
    expect(cocoon.count()).toBe 100
    expect(larva.count()).toBe 10
    inject.buy()
    expect(cocoon.count()).toBe 100 # no change
    expect(larva.count()).toBe 120 # 0 base larvae + 100 cloned cocoons + 10 cloned larvae + 10 starting larvae

  it 'sums costs', ->
    game = mkgame {territory:99}
    upgrade = game.upgrade 'expansion'
    expect(_.map upgrade.sumCost(1), (cost) -> [cost.unit.name, cost.val]).toEqual [['territory',100]]
    expect(_.map upgrade.sumCost(2), (cost) -> [cost.unit.name, cost.val]).toEqual [['territory',235]]

  it 'notices newly available upgrades', ->
    game = mkgame {territory:99}
    upgrade = game.upgrade 'expansion'
    expect(upgrade._lastUpgradeSeen).toEqual 0
    expect(upgrade.isNewlyUpgradable()).toBe false
    upgrade.viewNewUpgrades()
    expect(upgrade._lastUpgradeSeen).toEqual 0
    expect(upgrade.isNewlyUpgradable()).toBe false
    # we now have money for an upgrade
    game.unit('territory')._addCount 1
    expect(upgrade._lastUpgradeSeen).toEqual 0
    expect(upgrade.isNewlyUpgradable()).toBe true
    # upon seeing the upgrade with viewNewUpgrades(), remove the indicator
    upgrade.viewNewUpgrades()
    expect(upgrade._lastUpgradeSeen).toEqual 1
    expect(upgrade.isNewlyUpgradable()).toBe false
    # stays removed when upgrade bought
    upgrade.buy()
    expect(upgrade._lastUpgradeSeen).toEqual 0
    expect(upgrade.isNewlyUpgradable()).toBe false
    # we now have money for another upgrade, which disappears when viewNewUpgradesed
    game.unit('territory')._addCount 200
    expect(upgrade._lastUpgradeSeen).toEqual 0
    expect(upgrade.isNewlyUpgradable()).toBe true
    upgrade.viewNewUpgrades()
    expect(upgrade._lastUpgradeSeen).toEqual 1
    expect(upgrade.isNewlyUpgradable()).toBe false
    # money for a third upgrade does not make the indicator reappear, since we didn't buy upgrade #2
    game.unit('territory')._addCount 200
    upgrade.viewNewUpgrades()
    expect(upgrade._lastUpgradeSeen).toEqual 2
    expect(upgrade.isNewlyUpgradable()).toBe false

  it 'doesnt notice invisible upgrades, even if we can afford them. https://github.com/erosson/swarm/issues/94', ->
    game = mkgame {nest:25000}
    upgrade = game.upgrade 'nesttwin'
    expect(upgrade._lastUpgradeSeen).toEqual 0
    expect(upgrade.isNewlyUpgradable()).toBe false
    expect(upgrade.isVisible()).toBe false
    expect(upgrade.isCostMet()).toBe true
    # even though we can afford it, cannot view invisible upgrades
    upgrade.viewNewUpgrades()
    expect(upgrade._lastUpgradeSeen).toEqual 0
    expect(upgrade.isNewlyUpgradable()).toBe false
    expect(upgrade.isVisible()).toEqual false
    expect(upgrade.isCostMet()).toEqual true
    # we now have visibility, and the indicator!
    game.unit('greaterqueen')._addCount 1
    expect(upgrade._lastUpgradeSeen).toEqual 0
    expect(upgrade.isNewlyUpgradable()).toBe true
    expect(upgrade.isVisible()).toEqual true
    expect(upgrade.isCostMet()).toEqual true
    # goes away normally when viewed
    upgrade.viewNewUpgrades()
    expect(upgrade._lastUpgradeSeen).toBeGreaterThan 0
    expect(upgrade.isNewlyUpgradable()).toBe false
    expect(upgrade.isVisible()).toEqual true
    expect(upgrade.isCostMet()).toEqual true
