// =============================================================================
// Big Globe Ore Unification & Exclusive TFMG Metallurgy
// Enforces:
// 1. All Aluminum spawns/drops as Bauxite (tfmg:bauxite) -> Crushed to Bauxite Powder
//    -> Electrolyzed in TFMG Heated Chemical Vat with Electrodes.
// 2. All Steel, Cast Iron, Silicon, Constantan, and Bronze smelting/alloying
//    must go through Create: The Factory Must Grow (TFMG) & Create Basins.
// 3. Lead & Galena unification between TFMG and Mekanism.
// =============================================================================

if (typeof LootJS !== 'undefined') {
    LootJS.modifiers(event => {
        event.addTableModifier(LootType.BLOCK)
            .replaceLoot('#c:ores/aluminum', 'tfmg:bauxite', true)
            .replaceLoot('#c:ores/aluminium', 'tfmg:bauxite', true)
            .replaceLoot('#c:raw_materials/aluminum', 'tfmg:bauxite_powder', true)
            .replaceLoot('#c:raw_materials/aluminium', 'tfmg:bauxite_powder', true)
            .replaceLoot('mekanism:raw_lead', 'tfmg:raw_lead', true)
            .replaceLoot('mekanism:lead_ore', 'tfmg:lead_ore', true)
            .replaceLoot('mekanism:deepslate_lead_ore', 'tfmg:deepslate_lead_ore', true);
    });
}

ServerEvents.recipes(event => {

    // -------------------------------------------------------------------------
    // 1. EXCLUSIVE TFMG STEEL PRODUCTION (Виплавка сталі тільки через TFMG)
    // -------------------------------------------------------------------------
    // Remove Mekanism easy Steel shortcuts (Iron -> Enriched Iron -> Steel Dust -> Smelting)
    event.remove({ id: 'mekanism:processing/iron/enriched' });
    event.remove({ id: 'mekanism:processing/steel/enriched_iron_to_dust' });
    event.remove({ id: 'mekanism:infusion_conversion/carbon/from_enriched' });
    event.remove({ type: 'minecraft:smelting', output: '#c:ingots/steel' });
    event.remove({ type: 'minecraft:blasting', output: '#c:ingots/steel' });
    event.remove({ type: 'mekanism:smelting', output: '#c:ingots/steel' });

    // Fix mekanism_tfmg_compat bug where mekanism:block_steel unpacked into heavy_plate
    event.remove({ id: 'mekanism:processing/steel/ingot/from_block' });
    event.shapeless('9x tfmg:steel_ingot', ['mekanism:block_steel']);

    // Unify TFMG Steel Ingot <-> Mekanism Steel Ingot (after casting in TFMG)
    event.shapeless('mekanism:ingot_steel', ['tfmg:steel_ingot']);
    event.shapeless('tfmg:steel_ingot', ['mekanism:ingot_steel']);

    // -------------------------------------------------------------------------
    // 2. BAUXITE -> ALUMINUM UNIFICATION (Алюміній тільки з бокситу через TFMG)
    // -------------------------------------------------------------------------
    // Remove all direct smelting/blasting of Aluminum Dust/Ore into Ingots
    event.remove({ type: 'minecraft:smelting', output: '#c:ingots/aluminum' });
    event.remove({ type: 'minecraft:blasting', output: '#c:ingots/aluminum' });
    event.remove({ type: 'mekanism:smelting', output: '#c:ingots/aluminum' });
    event.remove({ id: 'moremekanismprocessing:processing/aluminum/ingot/from_dust_smelting' });
    event.remove({ id: 'moremekanismprocessing:processing/aluminum/ingot/from_dust_blasting' });

    // Allow Mekanism Crusher to crush Bauxite into TFMG Bauxite Powder (which must be electrolyzed in TFMG Vat)
    if (event.recipes.mekanism && event.recipes.mekanism.crushing) {
        event.recipes.mekanism.crushing('2x tfmg:bauxite_powder', 'tfmg:bauxite');
        event.recipes.mekanism.crushing('create:crushed_raw_lead', 'tfmg:galena');
    }

    // Convert any MoreMekanismProcessing Aluminum Dust into TFMG Bauxite Powder for Vat Electrolysis
    event.shapeless('2x tfmg:bauxite_powder', ['#c:dusts/aluminum']);
    event.shapeless('tfmg:aluminum_ingot', ['moremekanismprocessing:aluminum_ingot']);

    // -------------------------------------------------------------------------
    // 3. LEAD, NICKEL, LITHIUM & BRONZE METALLURGY UNIFICATION
    // -------------------------------------------------------------------------
    // Unify Lead Ingots & Raw Lead to TFMG
    event.shapeless('tfmg:lead_ingot', ['mekanism:ingot_lead']);
    event.shapeless('mekanism:ingot_lead', ['tfmg:lead_ingot']);
    event.shapeless('tfmg:raw_lead', ['mekanism:raw_lead']);

    // Remove trivial furnace smelting of Bronze Dust -> require Create Heated Mixing / Compacting
    event.remove({ id: 'mekanism:processing/bronze/ingot/from_dust_smelting' });
    event.remove({ id: 'mekanism:processing/bronze/ingot/from_dust_blasting' });

    if (event.recipes.create && event.recipes.create.mixing) {
        event.recipes.create.mixing('4x mekanism:ingot_bronze', [
            '#c:ingots/copper',
            '#c:ingots/copper',
            '#c:ingots/copper',
            '#c:ingots/tin'
        ]).heated();

        event.recipes.create.compacting('mekanism:ingot_bronze', [
            '#c:dusts/bronze'
        ]).heated();
    }

    // Remove direct ore-to-ingot furnace shortcuts for Lithium added by mekanism_tfmg_compat
    // (Lithium should be crushed into tfmg:crushed_raw_lithium first)
    event.remove({ id: 'mekanism_tfmg_compat:lithium/lithium_ore_smelting' });
    event.remove({ id: 'mekanism_tfmg_compat:lithium/lithium_ore_blasting' });
    event.remove({ id: 'mekanism_tfmg_compat:lithium/lithium_deepslate_ore_smelting' });
    event.remove({ id: 'mekanism_tfmg_compat:lithium/lithium_deepslate_ore_blasting' });

    console.info('KubeJS: Big Globe Bauxite/Galena & TFMG Exclusive Metallurgy loaded.');
});
