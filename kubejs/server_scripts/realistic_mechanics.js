// =============================================================================
// Realistic Industrial Mechanics & Metallurgy Overhaul
// Integrates: Create, The Factory Must Grow (TFMG) & Custom KubeJS items
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

    // Solder Wire (Припій)
    event.shaped('4x kubejs:solder_wire', [
        ' Z ',
        'LIL',
        ' Z '
    ], {
        Z: '#c:nuggets/zinc',
        L: '#c:nuggets/lead',
        I: 'minecraft:iron_nugget'
    });

    // Create mixing for Solder
    if (event.recipes.create && event.recipes.create.compacting) {
        event.recipes.create.compacting('8x kubejs:solder_wire', [
            '#c:ingots/zinc',
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
    // 3. INDUSTRIAL MACHINE FRAMES (Важке машинобудування)
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
    // Fallback without trusses (using steel ingots and plates)
    event.shaped('kubejs:industrial_machine_frame', [
        'SIS',
        'I I',
        'SIS'
    ], {
        S: '#c:ingots/steel',
        I: '#c:plates/steel'
    });


    // -------------------------------------------------------------------------
    // 4. CREATE REALISTIC PRECISION MECHANISM OVERHAUL (Прецизійний механізм)
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
