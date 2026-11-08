// =============================================================================
// Realistic Industrial Mechanics, Metallurgy & Nuclear/Fusion Engineering
// Integrates: Create, The Factory Must Grow (TFMG), Mekanism,
//             Mekanism Generators, Better Fusion Reactor (BFR), Mekanism Extras
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
    // 3. MEKANISM CONTROL CIRCUITS (Мікропроцесорні плати управління)
    // -------------------------------------------------------------------------
    event.remove({ output: 'mekanism:basic_control_circuit' });
    event.remove({ output: 'mekanism:advanced_control_circuit' });
    event.remove({ output: 'mekanism:elite_control_circuit' });
    event.remove({ output: 'mekanism:ultimate_control_circuit' });

    // Basic Control Circuit (Shaped fallback)
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

    // Advanced Control Circuit
    event.shaped('mekanism:advanced_control_circuit', [
        'WTW',
        'ACA',
        'SRS'
    ], {
        C: 'mekanism:basic_control_circuit',
        A: 'mekanism:alloy_infused',
        T: 'tfmg:transistor_item',
        R: 'tfmg:resistor',
        W: 'kubejs:solder_wire',
        S: 'kubejs:crude_semiconductor'
    });

    // Elite Control Circuit (Requires TFMG Aluminum & Capacitors)
    event.shaped('mekanism:elite_control_circuit', [
        'PKP',
        'ACA',
        'WSW'
    ], {
        C: 'mekanism:advanced_control_circuit',
        A: 'mekanism:alloy_reinforced',
        P: 'tfmg:aluminum_sheet',
        K: 'tfmg:capacitor_item',
        S: 'tfmg:circuit_board',
        W: 'kubejs:solder_wire'
    });

    // Ultimate Control Circuit (Requires HDPE, Silicon Wafers & Atomic Alloy)
    event.shaped('mekanism:ultimate_control_circuit', [
        'HSH',
        'ACA',
        'BEB'
    ], {
        C: 'mekanism:elite_control_circuit',
        A: 'mekanism:alloy_atomic',
        H: 'mekanism:hdpe_sheet',
        S: 'kubejs:silicon_wafer',
        B: 'tfmg:circuit_board',
        E: 'tfmg:electromagnetic_coil'
    });

    // Create Sequenced Assembly for Industrial Circuit Production
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
    // Fallback without trusses (using TFMG steel ingots and plates)
    event.shaped('kubejs:industrial_machine_frame', [
        'SIS',
        'I I',
        'SIS'
    ], {
        S: 'tfmg:steel_ingot',
        I: 'tfmg:heavy_plate'
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
        P: 'tfmg:steel_ingot',
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
        'WSW',
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
        'CLC',
        'LSL',
        'CLC'
    ], {
        S: 'mekanism:steel_casing',
        L: 'tfmg:lead_ingot',
        C: 'kubejs:insulated_cable'
    });

    // 5.6 Nuclear Fuel Cycle Machines (Машини ядерного паливного циклу)
    event.remove({ output: 'mekanism:isotopic_centrifuge' });
    event.remove({ output: 'mekanism:solar_neutron_activator' });
    event.remove({ output: 'mekanism:pressurized_reaction_chamber' });

    if (event.recipes.create && event.recipes.create.mechanical_crafting) {
        // Isotopic Centrifuge (Газова ультрацентрифуга для збагачення урану UF6)
        event.recipes.create.mechanical_crafting('mekanism:isotopic_centrifuge', [
            'LPPPL',
            'utRtu',
            'lTMTl',
            'utCtu',
            'LHBHL'
        ], {
            L: 'tfmg:lead_block',
            P: 'tfmg:steel_pipe',
            u: 'mekanism:ultimate_control_circuit',
            t: 'tfmg:aluminum_sheet',
            R: 'tfmg:rotor',
            l: 'tfmg:lead_sheet',
            T: 'mekanism:elite_chemical_tank',
            M: 'mekanism:steel_casing',
            C: 'tfmg:electric_motor',
            H: 'tfmg:heavy_plate',
            B: 'tfmg:heavy_machinery_casing'
        });

        // Solar Neutron Activator (Сонячний нейтронний активатор для отримання Полонію)
        event.recipes.create.mechanical_crafting('mekanism:solar_neutron_activator', [
            'SSSSS',
            'GAAAG',
            'LPBPL',
            'HCTCH',
            'LMMML'
        ], {
            S: 'mekanismgenerators:solar_panel',
            G: 'mekanismgenerators:reactor_glass',
            A: 'mekanism:hdpe_sheet',
            L: 'tfmg:lead_sheet',
            P: 'tfmg:aluminum_pipe',
            B: 'mekanism:laser_tractor_beam',
            H: 'tfmg:heavy_plate',
            C: 'mekanism:elite_control_circuit',
            T: 'mekanism:elite_chemical_tank',
            M: 'mekanism:steel_casing'
        });

        // Pressurized Reaction Chamber (Реакційна камера високого тиску)
        event.recipes.create.mechanical_crafting('mekanism:pressurized_reaction_chamber', [
            'HMPMH',
            'ACAGB',
            'TSEST',
            'HDCDH'
        ], {
            H: 'tfmg:heavy_plate',
            M: 'tfmg:steel_mechanism',
            P: 'tfmg:steel_mechanical_pump',
            A: 'mekanism:alloy_infused',
            C: 'mekanism:advanced_control_circuit',
            G: 'tfmg:steel_fluid_tank',
            B: 'mekanism:basic_chemical_tank',
            T: 'tfmg:steel_pipe',
            S: 'mekanism:enrichment_chamber',
            E: 'mekanism:steel_casing',
            D: 'mekanism:dynamic_tank'
        });
    }


    // -------------------------------------------------------------------------
    // 6. CREATE REALISTIC PRECISION MECHANISM OVERHAUL (Прецизійний механізм)
    // -------------------------------------------------------------------------
    if (event.recipes.create && event.recipes.create.sequenced_assembly) {
        event.remove({ output: 'create:precision_mechanism' });

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


    // -------------------------------------------------------------------------
    // 7. REALISTIC GENERATORS, NUCLEAR FISSION, STEAM TURBINE,
    //    THERMONUCLEAR FUSION (Mekanism + BFR) & NAQUADAH REACTORS
    // -------------------------------------------------------------------------
    if (event.recipes.create && event.recipes.create.mechanical_crafting) {

        // Remove all default trivial reactor & generator recipes
        const reactorAndGenOutputs = [
            'mekanismgenerators:heat_generator',
            'mekanismgenerators:wind_generator',
            'mekanismgenerators:gas_burning_generator',
            'mekanismgenerators:bio_generator',
            'mekanismgenerators:solar_panel',
            'mekanismgenerators:solar_generator',
            'mekanismgenerators:advanced_solar_generator',
            'mekanismgenerators:fission_reactor_casing',
            'mekanismgenerators:fission_reactor_port',
            'mekanismgenerators:fission_reactor_logic_adapter',
            'mekanismgenerators:fission_fuel_assembly',
            'mekanismgenerators:control_rod_assembly',
            'mekanismgenerators:reactor_glass',
            'mekanismgenerators:hohlraum',
            'mekanismgenerators:turbine_casing',
            'mekanismgenerators:turbine_valve',
            'mekanismgenerators:turbine_vent',
            'mekanismgenerators:turbine_rotor',
            'mekanismgenerators:turbine_blade',
            'mekanismgenerators:electromagnetic_coil',
            'mekanismgenerators:rotational_complex',
            'mekanismgenerators:saturating_condenser',
            'mekanismgenerators:fusion_reactor_controller',
            'mekanismgenerators:fusion_reactor_frame',
            'mekanismgenerators:fusion_reactor_port',
            'mekanismgenerators:fusion_reactor_logic_adapter',
            'mekanismgenerators:laser_focus_matrix',
            'bfr:fusion_reactor_controller',
            'bfr:fusion_reactor_frame',
            'bfr:fusion_reactor_port',
            'bfr:fusion_reactor_logic_adapter',
            'bfr:laser_focus_matrix',
            'bfr:irradiator',
            'mekanism_extras:naquadah_reactor_controller',
            'mekanism_extras:naquadah_reactor_port',
            'mekanism_extras:naquadah_reactor_logic_adapter',
            'mekanism_extras:lead_coated_laser_focus_matrix'
        ];
        reactorAndGenOutputs.forEach(item => event.remove({ output: item }));

        // --- 7.1 BASE INDUSTRIAL GENERATORS ---

        // Heat Generator (Термоелектричний генератор)
        event.recipes.create.mechanical_crafting('mekanismgenerators:heat_generator', [
            'HRRRH',
            'RWWWR',
            'PTSTP',
            'HGBGH',
            'HFFFH'
        ], {
            H: 'tfmg:heavy_plate',
            R: 'kubejs:refractory_brick',
            W: 'tfmg:constantan_wire',
            P: 'tfmg:steel_pipe',
            T: 'tfmg:steel_fluid_tank',
            S: 'mekanism:steel_casing',
            G: 'tfmg:generator',
            B: 'minecraft:blast_furnace',
            F: 'tfmg:fireproof_bricks'
        });

        // Wind Generator (Промисловий вітрогенератор)
        event.recipes.create.mechanical_crafting('mekanismgenerators:wind_generator', [
            '  B  ',
            ' BTB ',
            '  G  ',
            ' ASA ',
            ' HCH ',
            'HEMEH'
        ], {
            B: 'tfmg:turbine_blade',
            T: 'tfmg:rotor',
            G: 'tfmg:generator',
            A: 'tfmg:aluminum_sheet',
            S: 'tfmg:steel_encased_shaft',
            H: 'tfmg:heavy_plate',
            C: 'mekanism:steel_casing',
            E: 'mekanism:energy_tablet',
            M: 'mekanism:basic_control_circuit'
        });

        // Gas-Burning Generator (Газотурбінна електростанція)
        event.recipes.create.mechanical_crafting('mekanismgenerators:gas_burning_generator', [
            'HPPPH',
            'ATCTA',
            'MESEM',
            'ATGTA',
            'HBBBH'
        ], {
            H: 'tfmg:heavy_plate',
            P: 'tfmg:steel_pipe',
            A: 'mekanism:alloy_infused',
            T: 'mekanism:basic_chemical_tank',
            C: 'mekanism:advanced_control_circuit',
            M: 'tfmg:steel_mechanism',
            E: 'mekanism:electrolytic_core',
            S: 'mekanism:steel_casing',
            G: 'tfmg:turbine_engine',
            B: 'kubejs:refractory_brick'
        });

        // Bio-Generator (Біопаливний генератор)
        event.recipes.create.mechanical_crafting('mekanismgenerators:bio_generator', [
            'HIIIH',
            'GTCTG',
            'AMSMA',
            'HBPBH'
        ], {
            H: 'tfmg:heavy_plate',
            I: 'tfmg:steel_ingot',
            G: 'mekanism:structural_glass',
            T: 'tfmg:steel_fluid_tank',
            C: 'mekanism:basic_control_circuit',
            A: 'mekanism:alloy_infused',
            M: 'tfmg:generator',
            S: 'mekanism:steel_casing',
            B: 'mekanism:bio_fuel',
            P: 'tfmg:steel_mechanical_pump'
        });

        // Solar Panel (Фотоелектрична кремнієва панель)
        event.recipes.create.mechanical_crafting('mekanismgenerators:solar_panel', [
            'GGGGG',
            'WWWWW',
            'SAAAS',
            'ACCCA'
        ], {
            G: 'minecraft:glass_pane',
            W: 'kubejs:silicon_wafer',
            S: 'kubejs:solder_wire',
            A: 'tfmg:aluminum_sheet',
            C: 'kubejs:crude_semiconductor'
        });

        // Solar Generator (Сонячна електростанція)
        event.recipes.create.mechanical_crafting('mekanismgenerators:solar_generator', [
            'PPPPP',
            'AAAAA',
            ' WSW ',
            ' ECE ',
            ' HTH '
        ], {
            P: 'mekanismgenerators:solar_panel',
            A: 'tfmg:aluminum_sheet',
            W: 'kubejs:insulated_cable',
            S: 'mekanism:steel_casing',
            E: 'mekanism:energy_tablet',
            C: 'mekanism:basic_control_circuit',
            H: 'tfmg:heavy_plate',
            T: 'tfmg:steel_truss'
        });

        // Advanced Solar Generator (Високовольтна сонячна станція)
        event.recipes.create.mechanical_crafting('mekanismgenerators:advanced_solar_generator', [
            'SGSGS',
            'SGSGS',
            'AATAA',
            'TCTCT',
            '  T  ',
            ' HMH '
        ], {
            S: 'mekanismgenerators:solar_generator',
            G: 'mekanismgenerators:solar_panel',
            A: 'mekanism:alloy_infused',
            T: 'tfmg:steel_truss',
            C: 'mekanism:advanced_control_circuit',
            H: 'tfmg:heavy_plate',
            M: 'mekanism:steel_casing'
        });


        // --- 7.2 NUCLEAR FISSION REACTOR (Реактор ядерного поділу ВВЕР/РБМК) ---

        // Reactor Glass (Освинцьоване боросилікатне радіаційне скло)
        event.recipes.create.mechanical_crafting('4x mekanismgenerators:reactor_glass', [
            'HLLLH',
            'LGGGL',
            'LGQGL',
            'LGGGL',
            'HLLLH'
        ], {
            H: 'tfmg:heavy_plate',
            L: 'tfmg:lead_sheet',
            G: 'mekanism:structural_glass',
            Q: 'minecraft:tinted_glass'
        });

        // Fission Reactor Casing (Біологічний захист та корпус ядерного реактора)
        event.recipes.create.mechanical_crafting('4x mekanismgenerators:fission_reactor_casing', [
            'HCCCH',
            'CLLLC',
            'LRSRL',
            'CLLLC',
            'HCCCH'
        ], {
            H: 'tfmg:heavy_plate',
            C: 'tfmg:rebar_concrete',
            L: 'tfmg:lead_block',
            R: 'kubejs:refractory_brick',
            S: 'mekanism:steel_casing'
        });

        // Fission Reactor Port (Клапан першого контуру теплоносія)
        event.recipes.create.mechanical_crafting('2x mekanismgenerators:fission_reactor_port', [
            'HCFCH',
            'CPLPC',
            'FLVLF',
            'CPMPC',
            'HCFCH'
        ], {
            H: 'tfmg:heavy_plate',
            C: 'mekanismgenerators:fission_reactor_casing',
            F: 'tfmg:steel_frame',
            P: 'tfmg:steel_smart_fluid_pipe',
            L: 'tfmg:lead_sheet',
            V: 'tfmg:steel_mechanical_pump',
            M: 'mekanism:elite_control_circuit'
        });

        // Fission Reactor Logic Adapter (Блок аварійного захисту та телеметрії АЗ-5)
        event.recipes.create.mechanical_crafting('mekanismgenerators:fission_reactor_logic_adapter', [
            'HWRWH',
            'WECEW',
            'RCFCR',
            'WECEW',
            'HWRWH'
        ], {
            H: 'tfmg:heavy_plate',
            W: 'kubejs:insulated_cable',
            R: 'minecraft:repeater',
            E: 'mekanism:elite_control_circuit',
            C: 'tfmg:circuit_board',
            F: 'mekanismgenerators:fission_reactor_casing'
        });

        // Fission Fuel Assembly (Тепловидільна збірка ТВЗ з цирконієво-сталевими трубками)
        event.recipes.create.mechanical_crafting('mekanismgenerators:fission_fuel_assembly', [
            'HLALH',
            'lPTPl',
            'lPTPl',
            'lPTPl',
            'lPTPl',
            'HLALH'
        ], {
            H: 'tfmg:heavy_plate',
            L: 'tfmg:lead_block',
            A: 'mekanism:alloy_atomic',
            l: 'tfmg:lead_sheet',
            P: 'tfmg:steel_pipe',
            T: 'mekanism:elite_chemical_tank'
        });

        // Control Rod Assembly (Привід стержнів керування і захисту СУЗ з графітовими поглиначами)
        event.recipes.create.mechanical_crafting('mekanismgenerators:control_rod_assembly', [
            'HUMUH',
            'LCICL',
            'LEFEL',
            'LEFEL',
            'LEFEL'
        ], {
            H: 'tfmg:heavy_plate',
            U: 'mekanism:ultimate_control_circuit',
            M: 'tfmg:electric_motor',
            L: 'tfmg:lead_sheet',
            C: 'mekanism:steel_casing',
            I: 'tfmg:steel_mechanism',
            E: 'tfmg:graphite_electrode',
            F: 'mekanismgenerators:fission_fuel_assembly'
        });


        // --- 7.3 INDUSTRIAL STEAM TURBINE (Парова турбіна високого тиску) ---

        // Turbine Casing (Корпус парової турбіни)
        event.recipes.create.mechanical_crafting('4x mekanismgenerators:turbine_casing', [
            'HTPTH',
            'TLLLT',
            'PLSLP',
            'TLLLT',
            'HTPTH'
        ], {
            H: 'tfmg:heavy_plate',
            T: 'tfmg:steel_truss',
            P: 'tfmg:industrial_pipe',
            L: 'tfmg:steel_ingot',
            S: 'mekanism:steel_casing'
        });

        // Turbine Valve (Паровпускний клапан високого тиску)
        event.recipes.create.mechanical_crafting('2x mekanismgenerators:turbine_valve', [
            'HCTCH',
            'CPVPC',
            'TVMVT',
            'CPAPC',
            'HCTCH'
        ], {
            H: 'tfmg:heavy_plate',
            C: 'mekanismgenerators:turbine_casing',
            T: 'tfmg:industrial_pipe',
            P: 'tfmg:steel_pipe',
            V: 'tfmg:steel_fluid_valve',
            M: 'tfmg:steel_mechanical_pump',
            A: 'mekanism:advanced_control_circuit'
        });

        // Turbine Vent (Конденсаційний витяжний дефлектор)
        event.recipes.create.mechanical_crafting('2x mekanismgenerators:turbine_vent', [
            'HBBBH',
            'BFCFB',
            'BCACB',
            'BFCFB',
            'HBBBH'
        ], {
            H: 'tfmg:heavy_plate',
            B: 'tfmg:steel_bars',
            F: 'create:encased_fan',
            C: 'mekanismgenerators:turbine_casing',
            A: 'tfmg:aluminum_frame'
        });

        // Turbine Blade (Лопатка турбіни з жароміцного сплаву)
        event.recipes.create.mechanical_crafting('2x mekanismgenerators:turbine_blade', [
            '  H  ',
            ' HTH ',
            'HTATH',
            ' HIH ',
            '  S  '
        ], {
            H: 'tfmg:heavy_plate',
            T: 'tfmg:turbine_blade',
            A: 'mekanism:alloy_infused',
            I: 'tfmg:steel_ingot',
            S: 'tfmg:screw'
        });

        // Turbine Rotor (Роторний вал парової турбіни)
        event.recipes.create.mechanical_crafting('mekanismgenerators:turbine_rotor', [
            'HSMSH',
            ' HIH ',
            ' HIH ',
            ' HIH ',
            'HSMSH'
        ], {
            H: 'tfmg:heavy_plate',
            S: 'tfmg:steel_mechanism',
            M: 'mekanism:alloy_reinforced',
            I: 'tfmg:steel_encased_shaft'
        });

        // Rotational Complex (Редукторно-роторний вузол синхронізації)
        event.recipes.create.mechanical_crafting('mekanismgenerators:rotational_complex', [
            'HMGMH',
            'MRCRM',
            'GCACG',
            'MRCRM',
            'HMGMH'
        ], {
            H: 'tfmg:heavy_plate',
            M: 'tfmg:steel_mechanism',
            G: 'tfmg:steel_gearbox',
            R: 'tfmg:rotor',
            C: 'mekanism:elite_control_circuit',
            A: 'tfmg:heavy_machinery_casing'
        });

        // Electromagnetic Coil (Високовольтна обмотка статора турбогенератора)
        event.recipes.create.mechanical_crafting('mekanismgenerators:electromagnetic_coil', [
            'HLLLH',
            'LECEL',
            'LSSSL',
            'LECEL',
            'HLLLH'
        ], {
            H: 'tfmg:heavy_plate',
            L: 'tfmg:large_coil',
            E: 'tfmg:electromagnetic_coil',
            C: 'mekanism:elite_control_circuit',
            S: 'tfmg:laminated_magnetic_alloy_block'
        });

        // Saturating Condenser (Теплообмінний конденсатор пари)
        event.recipes.create.mechanical_crafting('mekanismgenerators:saturating_condenser', [
            'HPPPH',
            'PAAAP',
            'PTSTP',
            'PAAAP',
            'HPPPH'
        ], {
            H: 'tfmg:heavy_plate',
            P: 'tfmg:steel_pipe',
            A: 'tfmg:aluminum_pipe',
            T: 'tfmg:steel_fluid_tank',
            S: 'mekanism:steel_casing'
        });


        // --- 7.4 THERMONUCLEAR FUSION REACTOR (Токамак: MekanismGenerators & BetterFusionReactor) ---

        // Hohlraum (Золота капсула-мішень інерційного термоядерного синтезу)
        event.recipes.create.mechanical_crafting('mekanismgenerators:hohlraum', [
            ' LGL ',
            'GDDDG',
            'GDADG',
            'GDDDG',
            ' LGL '
        ], {
            L: 'tfmg:lead_sheet',
            G: '#c:plates/gold',
            D: 'mekanism:dust_lithium',
            A: 'mekanism:alloy_atomic'
        });

        // Fusion Reactor Frame (Надпровідний магнітний бланкет токамака - Mekanism & BFR)
        const fusionFrames = ['2x mekanismgenerators:fusion_reactor_frame', '2x bfr:fusion_reactor_frame'];
        fusionFrames.forEach(outputFrame => {
            event.recipes.create.mechanical_crafting(outputFrame, [
                'HAAAH',
                'APFPA',
                'AFXFA',
                'APFPA',
                'HAAAH'
            ], {
                H: 'tfmg:heavy_plate',
                A: 'mekanism:alloy_atomic',
                P: 'mekanism:pellet_polonium',
                F: 'tfmg:reinforced_fireproof_bricks',
                X: 'mekanism:steel_casing'
            });
        });

        // Fusion Reactor Controller (Центральний соленоїд та комп'ютер управління плазмою)
        event.recipes.create.mechanical_crafting('mekanismgenerators:fusion_reactor_controller', [
            'FFUUUFF',
            'FGGGGGF',
            'UGMTMGU',
            'UGPCPGU',
            'UGMTMGU',
            'FGGGGGF',
            'FFUUUFF'
        ], {
            F: 'mekanismgenerators:fusion_reactor_frame',
            U: 'mekanism:ultimate_control_circuit',
            G: 'mekanismgenerators:reactor_glass',
            M: 'tfmg:laminated_magnetic_alloy_block',
            T: 'mekanism:ultimate_chemical_tank',
            P: 'mekanism:pellet_polonium',
            C: 'mekanism:teleportation_core'
        });

        event.recipes.create.mechanical_crafting('bfr:fusion_reactor_controller', [
            'FFUUUFF',
            'FGGGGGF',
            'UGMTMGU',
            'UGPCPGU',
            'UGMTMGU',
            'FGGGGGF',
            'FFUUUFF'
        ], {
            F: 'bfr:fusion_reactor_frame',
            U: 'mekanism:ultimate_control_circuit',
            G: 'mekanismgenerators:reactor_glass',
            M: 'tfmg:laminated_magnetic_alloy_block',
            T: 'mekanism:ultimate_chemical_tank',
            P: 'mekanism:pellet_polonium',
            C: 'mekanism:teleportation_core'
        });

        // Fusion Reactor Port (Кріогенний порт подачі дейтерію-тритію та відводу енергії)
        event.recipes.create.mechanical_crafting('2x mekanismgenerators:fusion_reactor_port', [
            'FFPFF',
            'FUUUF',
            'PUTUP',
            'FUUUF',
            'FFPFF'
        ], {
            F: 'mekanismgenerators:fusion_reactor_frame',
            P: 'mekanism:pellet_polonium',
            U: 'mekanism:ultimate_control_circuit',
            T: 'mekanism:ultimate_chemical_tank'
        });

        event.recipes.create.mechanical_crafting('2x bfr:fusion_reactor_port', [
            'FFPFF',
            'FUUUF',
            'PUTUP',
            'FUUUF',
            'FFPFF'
        ], {
            F: 'bfr:fusion_reactor_frame',
            P: 'mekanism:pellet_polonium',
            U: 'mekanism:ultimate_control_circuit',
            T: 'mekanism:ultimate_chemical_tank'
        });

        // Fusion Reactor Logic Adapter (Діагностичний контролер стабільності плазми)
        event.recipes.create.mechanical_crafting('mekanismgenerators:fusion_reactor_logic_adapter', [
            'FFRFF',
            'FCCCF',
            'RCUCR',
            'FCCCF',
            'FFRFF'
        ], {
            F: 'mekanismgenerators:fusion_reactor_frame',
            R: 'minecraft:redstone_block',
            C: 'tfmg:circuit_board',
            U: 'mekanism:ultimate_control_circuit'
        });

        event.recipes.create.mechanical_crafting('bfr:fusion_reactor_logic_adapter', [
            'FFRFF',
            'FCCCF',
            'RCUCR',
            'FCCCF',
            'FFRFF'
        ], {
            F: 'bfr:fusion_reactor_frame',
            R: 'minecraft:redstone_block',
            C: 'tfmg:circuit_board',
            U: 'mekanism:ultimate_control_circuit'
        });

        // Laser Focus Matrix (Матриця фокусування надпотужного лазера запалювання плазми)
        event.recipes.create.mechanical_crafting('mekanismgenerators:laser_focus_matrix', [
            'GAAAG',
            'ALLLA',
            'ALCLA',
            'ALLLA',
            'GAAAG'
        ], {
            G: 'mekanismgenerators:reactor_glass',
            A: 'mekanism:alloy_atomic',
            L: 'mekanism:laser_amplifier',
            C: 'mekanism:teleportation_core'
        });

        event.recipes.create.mechanical_crafting('bfr:laser_focus_matrix', [
            'GAAAG',
            'ALLLA',
            'ALCLA',
            'ALLLA',
            'GAAAG'
        ], {
            G: 'mekanismgenerators:reactor_glass',
            A: 'mekanism:alloy_atomic',
            L: 'mekanism:laser_amplifier',
            C: 'mekanism:teleportation_core'
        });

        // BFR Irradiator (Камера нейтронного опромінення термоядерного реактора)
        event.recipes.create.mechanical_crafting('bfr:irradiator', [
            'FUUUF',
            'UGGGU',
            'LBTBL',
            'UGGGU',
            'FUUUF'
        ], {
            F: 'bfr:fusion_reactor_frame',
            U: 'mekanism:ultimate_control_circuit',
            G: 'mekanismgenerators:reactor_glass',
            L: 'mekanism:laser_tractor_beam',
            B: 'tfmg:lead_block',
            T: 'mekanism:ultimate_chemical_tank'
        });

        // Convenient 1:1 conversions between MekanismGenerators Fusion parts and BFR Fusion parts
        event.shapeless('bfr:fusion_reactor_frame', ['mekanismgenerators:fusion_reactor_frame']);
        event.shapeless('mekanismgenerators:fusion_reactor_frame', ['bfr:fusion_reactor_frame']);
        event.shapeless('bfr:fusion_reactor_controller', ['mekanismgenerators:fusion_reactor_controller']);
        event.shapeless('mekanismgenerators:fusion_reactor_controller', ['bfr:fusion_reactor_controller']);
        event.shapeless('bfr:fusion_reactor_port', ['mekanismgenerators:fusion_reactor_port']);
        event.shapeless('mekanismgenerators:fusion_reactor_port', ['bfr:fusion_reactor_port']);
        event.shapeless('bfr:fusion_reactor_logic_adapter', ['mekanismgenerators:fusion_reactor_logic_adapter']);
        event.shapeless('mekanismgenerators:fusion_reactor_logic_adapter', ['bfr:fusion_reactor_logic_adapter']);
        event.shapeless('bfr:laser_focus_matrix', ['mekanismgenerators:laser_focus_matrix']);
        event.shapeless('mekanismgenerators:laser_focus_matrix', ['bfr:laser_focus_matrix']);


        // --- 7.5 NAQUADAH ULTRADENSE REACTOR (Mekanism Extras) ---

        // Naquadah Reactor Casing (Надважкий антиматерійно-наквадаховий корпус)
        event.recipes.create.mechanical_crafting('2x mekanism_extras:naquadah_reactor_casing', [
            'LTTTTTL',
            'TFFFFFT',
            'TFNNNFT',
            'TFNANFT',
            'TFNNNFT',
            'TFFFFFT',
            'LTTTTTL'
        ], {
            L: 'tfmg:lead_block',
            T: 'mekanism_extras:alloy_thermonuclear',
            F: 'bfr:fusion_reactor_frame',
            N: 'mekanism_extras:ingot_naquadah',
            A: 'mekanism:pellet_antimatter'
        });

        // Naquadah Reactor Controller (Космічний контролер наквадахового синтезу)
        event.recipes.create.mechanical_crafting('mekanism_extras:naquadah_reactor_controller', [
            'CCCCCCC',
            'CKGGGKC',
            'CGSTSGC',
            'CGTATGC',
            'CGSTSGC',
            'CKGGGKC',
            'CCCCCCC'
        ], {
            C: 'mekanism_extras:naquadah_reactor_casing',
            K: 'mekanism_extras:cosmic_control_circuit',
            G: 'mekanismgenerators:reactor_glass',
            S: 'mekanism_extras:alloy_shining',
            T: 'mekanism_extras:absolute_chemical_tank',
            A: 'mekanism:pellet_antimatter'
        });

        // Naquadah Reactor Port
        event.recipes.create.mechanical_crafting('2x mekanism_extras:naquadah_reactor_port', [
            'CCKCC',
            'CSSSC',
            'KSTSK',
            'CSSSC',
            'CCKCC'
        ], {
            C: 'mekanism_extras:naquadah_reactor_casing',
            K: 'mekanism_extras:cosmic_control_circuit',
            S: 'mekanism_extras:alloy_shining',
            T: 'mekanism_extras:absolute_chemical_tank'
        });

        // Naquadah Reactor Logic Adapter
        event.recipes.create.mechanical_crafting('mekanism_extras:naquadah_reactor_logic_adapter', [
            'CCRCC',
            'CBBBC',
            'RBKBR',
            'CBBBC',
            'CCRCC'
        ], {
            C: 'mekanism_extras:naquadah_reactor_casing',
            R: 'minecraft:redstone_block',
            B: 'tfmg:circuit_board',
            K: 'mekanism_extras:cosmic_control_circuit'
        });

        // Lead-Coated Laser Focus Matrix (Освинцьована лазерна матриця наквадахового реактора)
        event.recipes.create.mechanical_crafting('mekanism_extras:lead_coated_laser_focus_matrix', [
            'LLTLL',
            'LMMML',
            'TMNMT',
            'LMMML',
            'LLTLL'
        ], {
            L: 'tfmg:lead_block',
            T: 'mekanism_extras:alloy_thermonuclear',
            M: 'mekanismgenerators:laser_focus_matrix',
            N: 'mekanism_extras:block_naquadah'
        });
    }

    console.info('KubeJS: Realistic Industrial Mechanics, TFMG Metallurgy & Nuclear/Fusion Reactors loaded!');
});
