// =============================================================================
// Uranium Unification: Create Nuclear & Mekanism
// 1. Unifies block drops: all uranium ores drop radioactive Create Nuclear raw uranium.
// 2. Provides 1:1 bidirectional conversion recipes between both mods' items/blocks.
// 3. Ensures complete smelting/blasting compatibility into Mekanism Uranium Ingots.
// =============================================================================

if (typeof LootJS !== 'undefined') {
    LootJS.modifiers(event => {
        event.addTableModifier(LootType.BLOCK)
            .replaceLoot('mekanism:raw_uranium', 'createnuclear:raw_uranium', true)
            .replaceLoot('mekanism:uranium_ore', 'createnuclear:uranium_ore', true)
            .replaceLoot('mekanism:deepslate_uranium_ore', 'createnuclear:deepslate_uranium_ore', true);
    });
}

ServerEvents.recipes(event => {
    // 1:1 Bidirectional conversions between Create Nuclear & Mekanism
    event.shapeless('createnuclear:raw_uranium', ['mekanism:raw_uranium']);
    event.shapeless('mekanism:raw_uranium', ['createnuclear:raw_uranium']);

    event.shapeless('createnuclear:raw_uranium_block', ['mekanism:block_raw_uranium']);
    event.shapeless('mekanism:block_raw_uranium', ['createnuclear:raw_uranium_block']);

    event.shapeless('createnuclear:uranium_ore', ['mekanism:uranium_ore']);
    event.shapeless('mekanism:uranium_ore', ['createnuclear:uranium_ore']);

    event.shapeless('createnuclear:deepslate_uranium_ore', ['mekanism:deepslate_uranium_ore']);
    event.shapeless('mekanism:deepslate_uranium_ore', ['createnuclear:deepslate_uranium_ore']);

    // Smelting & Blasting to Mekanism Uranium Ingot
    event.smelting('mekanism:ingot_uranium', 'createnuclear:raw_uranium').xp(0.6);
    event.blasting('mekanism:ingot_uranium', 'createnuclear:raw_uranium').xp(0.6);

    event.smelting('mekanism:ingot_uranium', 'createnuclear:uranium_ore').xp(0.8);
    event.blasting('mekanism:ingot_uranium', 'createnuclear:uranium_ore').xp(0.8);

    event.smelting('mekanism:ingot_uranium', 'createnuclear:deepslate_uranium_ore').xp(0.8);
    event.blasting('mekanism:ingot_uranium', 'createnuclear:deepslate_uranium_ore').xp(0.8);
});
