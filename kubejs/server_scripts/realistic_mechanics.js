// =============================================================================
// Realistic Industrial Mechanics & Metallurgy Overhaul
// Integrates: Create, The Factory Must Grow (TFMG), Mekanism & Custom KubeJS items
// =============================================================================

ServerEvents.recipes(event => {

    // -------------------------------------------------------------------------
    // 1. REFRACTORY & CERAMIC MATERIALS (Вогнетривкі матеріали для плавки)
    // -------------------------------------------------------------------------
    
    // Unfired Refractory Brick (Сира шамотна цегла)
    event.shaped('2x kubejs:unfired_refractory_brick', [
        'CS',
        'QC'
    ], {
        C: 'minecraft:clay_ball',
        S: 'minecraft:sand',
        Q: 'minecraft:quartz'
    });

    // Fallback using flint instead of quartz
    event.shaped('2x kubejs:unfired_refractory_brick', [
        'CF',
        'SC'
    ], {
        C: 'minecraft:clay_ball',
        S: 'minecraft:sand',
        F: 'minecraft:flint'
    });

    // Smelting & Blasting to fired Refractory Brick
    event.smelting('kubejs:refractory_brick', 'kubejs:unfired_refractory_brick').xp(0.2);
    event.blasting('kubejs:refractory_brick', 'kubejs:unfired_refractory_brick').xp(0.2);


    // -------------------------------------------------------------------------
    // 2. ELECTRONICS & SOLDERING (Радіоелектроніка та паяння)
    // -------------------------------------------------------------------------

    // Solder Wire (Олов'яно-свинцевий припій 60/40)
    // Crafting table fallback
    event.shaped('4x kubejs:solder_wire', [
        ' T ',
        'LIL',
        ' T '
    ], {
        T: '#c:nuggets/tin',
        L: '#c:nuggets/lead',
        I: 'minecraft:iron_nugget'
    });

    // Create mixing for Solder
    if (event.recipes.create && event.recipes.create.compacting) {
        event.recipes.create.compacting('8x kubejs:solder_wire', [
            '#c:ingots/tin',
            '#c:ingots/lead'
        ]).heated();
    }

    // Electronic Components (Резистори та конденсатори)
    event.shaped('4x kubejs:electronic_components', [
        ' W ',
        'RTR',
        ' W '
    ], {
        W: '#c:wires/copper',
        R: 'minecraft:redstone',
        T: 'minecraft:terracotta'
    });

    // Fallback if c:wires/copper tag is empty
    event.shaped('4x kubejs:electronic_components', [
        ' N ',
        'RTR',
        ' N '
    ], {
        N: 'minecraft:copper_ingot',
        R: 'minecraft:redstone',
        T: 'minecraft:clay_ball'
    });

    // Slicing Silicon Wafers from TFMG Silicon Ingot
    event.stonecutting('4x kubejs:silicon_wafer', 'tfmg:silicon_ingot');
    if (event.recipes.create && event.recipes.create.cutting) {
        event.recipes.create.cutting('4x kubejs:silicon_wafer', 'tfmg:silicon_ingot');
    }
    // Fallback if player doesn't have silicon ingot yet (using quartz block)
    event.stonecutting('2x kubejs:silicon_wafer', 'minecraft:quartz_block');

    // Crude Semiconductor Microchip (Напівпровідниковий кристал)
    event.shaped('2x kubejs:crude_semiconductor', [
        ' R ',
        'GWG',
        ' N '
    ], {
        W: 'kubejs:silicon_wafer',
        R: 'minecraft:redstone',
        G: 'minecraft:gold_nugget',
        N: 'minecraft:iron_nugget'
    });

    // Empty Circuit Board (Текстолітова заготовка)
    event.shaped('2x kubejs:empty_pcb', [
        'CCC',
        'PPP',
        'CCC'
    ], {
        C: '#c:plates/copper',
        P: 'tfmg:plastic_sheet'
    });
    // Fallback without plastic (treated planks / resin)
    event.shaped('kubejs:empty_pcb', [
        ' C ',
        ' W ',
        ' C '
    ], {
        C: 'minecraft:copper_ingot',
        W: 'minecraft:dried_kelp'
    });

    // Etched PCB (Витравлена плата з мідними доріжками)
    event.shaped('kubejs:etched_pcb', [
        ' R ',
        'RPR',
        ' I '
    ], {
        P: 'kubejs:empty_pcb',
        R: 'minecraft:redstone',
        I: 'minecraft:iron_nugget'
    });

    // Insulated Copper Cable (Ізольований кабель)
    event.shaped('4x kubejs:insulated_cable', [
        ' R ',
        'RWR',
        ' R '
    ], {
        W: 'minecraft:copper_ingot',
        R: 'tfmg:rubber_sheet'
    });
    // Fallback with dried kelp
    event.shaped('2x kubejs:insulated_cable', [
        ' K ',
        'KWK',
        ' K '
    ], {
        W: 'minecraft:copper_ingot',
        K: 'minecraft:dried_kelp'
    });


    // -------------------------------------------------------------------------
    // 3. MEKANISM BASIC CONTROL CIRCUIT (Мікропроцесорна плата управління)
    // -------------------------------------------------------------------------
    // Remove trivial old recipe
    event.remove({ output: 'mekanism:basic_control_circuit' });

    // Realistic Shaped Crafting
    event.shaped('mekanism:basic_control_circuit', [
        ' C ',
        'ESE',
        ' W '
    ], {
        C: 'create:electron_tube',
        E: 'kubejs:electronic_components',
        S: 'kubejs:crude_semiconductor',
        W: 'kubejs:solder_wire'
    });

    // Advanced Create Sequenced Assembly for Industrial Production
    if (event.recipes.create && event.recipes.create.sequenced_assembly) {
        event.recipes.create.sequenced_assembly([
            'mekanism:basic_control_circuit'
        ], 'kubejs:etched_pcb', [
            event.recipes.create.deploying('kubejs:etched_pcb', ['kubejs:etched_pcb', 'kubejs:crude_semiconductor']),
            event.recipes.create.deploying('kubejs:etched_pcb', ['kubejs:etched_pcb', 'kubejs:electronic_components']),
            event.recipes.create.deploying('kubejs:etched_pcb', ['kubejs:etched_pcb', 'kubejs:solder_wire']),
            event.recipes.create.deploying('kubejs:etched_pcb', ['kubejs:etched_pcb', 'create:electron_tube']),
            event.recipes.create.pressing('kubejs:etched_pcb', 'kubejs:etched_pcb')
        ]).transitionalItem('kubejs:etched_pcb').loops(1);
    }


    // -------------------------------------------------------------------------
    // 4. INDUSTRIAL MACHINE FRAMES & STEEL CASING (Важке машинобудування)
    // -------------------------------------------------------------------------
    
    // Industrial Machine Frame
    event.shaped('kubejs:industrial_machine_frame', [
        'HTH',
        'T T',
        'HTH'
    ], {
        H: 'tfmg:heavy_plate',
        T: 'tfmg:steel_truss'
    });
    // Fallback without trusses (using steel ingots and brass)
    event.shaped('kubejs:industrial_machine_frame', [
        'SIS',
        'I I',
        'SIS'
    ], {
        S: '#c:ingots/steel',
        I: '#c:plates/steel'
    });

    // Overhaul Mekanism Steel Casing (Корпус механізмів Mekanism)
    event.remove({ output: 'mekanism:steel_casing' });

    event.shaped('mekanism:steel_casing', [
        'PMP',
        'GFG',
        'PMP'
    ], {
        F: 'kubejs:industrial_machine_frame',
        M: 'tfmg:steel_mechanism',
        P: 'tfmg:heavy_plate',
        G: 'mekanism:structural_glass'
    });
    // Fallback if structural glass not crafted yet
    event.shaped('mekanism:steel_casing', [
        'PMP',
        'GFG',
        'PMP'
    ], {
        F: 'kubejs:industrial_machine_frame',
        M: 'create:precision_mechanism',
        P: '#c:ingots/steel',
        G: 'minecraft:tinted_glass'
    });


    // -------------------------------------------------------------------------
    // 5. MEKANISM CORE MACHINES OVERHAUL (Складні промислові машини)
    // -------------------------------------------------------------------------

    // 5.1 Metallurgic Infuser (Металургійний інфузер)
    event.remove({ output: 'mekanism:metallurgic_infuser' });
    event.shaped('mekanism:metallurgic_infuser', [
        'RBR',
        'CSC',
        'RBR'
    ], {
        S: 'mekanism:steel_casing',
        B: 'kubejs:refractory_brick',
        C: 'mekanism:basic_control_circuit',
        R: 'tfmg:copper_spool'
    });
    // Fallback if no copper spool yet
    event.shaped('mekanism:metallurgic_infuser', [
        'RBR',
        'CSC',
        'RBR'
    ], {
        S: 'mekanism:steel_casing',
        B: 'kubejs:refractory_brick',
        C: 'mekanism:basic_control_circuit',
        R: 'kubejs:insulated_cable'
    });

    // 5.2 Enrichment Chamber (Камера збагачення руд)
    event.remove({ output: 'mekanism:enrichment_chamber' });
    event.shaped('mekanism:enrichment_chamber', [
        'CWC',
        'PSP',
        'CWC'
    ], {
        S: 'mekanism:steel_casing',
        W: 'create:crushing_wheel',
        C: 'mekanism:basic_control_circuit',
        P: 'create:mechanical_piston'
    });

    // 5.3 Crusher (Промисловий подрібнювач)
    event.remove({ output: 'mekanism:crusher' });
    event.shaped('mekanism:crusher', [
        'CMC',
        'W S W',
        'CMC'
    ], {
        S: 'mekanism:steel_casing',
        W: 'create:crushing_wheel',
        C: 'mekanism:basic_control_circuit',
        M: 'tfmg:steel_mechanism'
    });

    // 5.4 Energized Smelter (Електрична плавильня)
    event.remove({ output: 'mekanism:energized_smelter' });
    event.shaped('mekanism:energized_smelter', [
        'RBR',
        'CSC',
        'RBR'
    ], {
        S: 'mekanism:steel_casing',
        B: 'kubejs:refractory_brick',
        C: 'mekanism:basic_control_circuit',
        R: 'tfmg:constantan_wire'
    });

    // 5.5 Basic Energy Cube (Базовий накопичувач енергії)
    event.remove({ output: 'mekanism:basic_energy_cube' });
    event.shaped('mekanism:basic_energy_cube', [
        'CAC',
        'ASA',
        'CAC'
    ], {
        S: 'mekanism:steel_casing',
        A: 'tfmg:accumulator',
        C: 'kubejs:insulated_cable'
    });
    // Fallback if accumulator not ready
    event.shaped('mekanism:basic_energy_cube', [
        'CL C',
        'LSL',
        'CL C'
    ], {
        S: 'mekanism:steel_casing',
        L: '#c:ingots/lead',
        C: 'kubejs:insulated_cable'
    });


    // -------------------------------------------------------------------------
    // 6. CREATE REALISTIC PRECISION MECHANISM OVERHAUL (Прецизійний механізм)
    // -------------------------------------------------------------------------
    if (event.recipes.create && event.recipes.create.sequenced_assembly) {
        event.remove({ output: 'create:precision_mechanism' });

        // Advanced realistic assembly line: Clockwork gear teeth + solder + electron tube
        event.recipes.create.sequenced_assembly([
            'create:precision_mechanism'
        ], '#c:plates/brass', [
            event.recipes.create.deploying('create:incomplete_precision_mechanism', ['create:incomplete_precision_mechanism', 'create:cogwheel']),
            event.recipes.create.deploying('create:incomplete_precision_mechanism', ['create:incomplete_precision_mechanism', 'create:large_cogwheel']),
            event.recipes.create.deploying('create:incomplete_precision_mechanism', ['create:incomplete_precision_mechanism', 'kubejs:solder_wire']),
            event.recipes.create.deploying('create:incomplete_precision_mechanism', ['create:incomplete_precision_mechanism', 'create:electron_tube']),
            event.recipes.create.pressing('create:incomplete_precision_mechanism', 'create:incomplete_precision_mechanism')
        ]).transitionalItem('create:incomplete_precision_mechanism').loops(3);
    }

    console.info('KubeJS: Realistic Industrial Mechanics & Metallurgy loaded successfully!');
});
