import QtQuick
import QtTest
import "../services"
import "../components"
import "../services/DisplayGeometry.js" as Geometry

Item {
    width:1000;height:600
    function displays(){return ["A","B","C"].map((name,i)=>({name:name,key:name,number:i+1,width:1920,height:1080,refreshRate:59.997,scale:1,transform:0,x:i*1920,y:0,disabled:false,mirrorOf:"none",availableModes:["1920x1080@60.00Hz","1280x720@60.00Hz"]}));}
    DisplayDraft {id:draft;observedDigest:"baseline"}
    DisplayCanvas {id:canvas;width:1000;height:400;draft:draft}
    TestCase {
        name:"DisplayCanvas";when:windowShown
        function init(){draft.discard();draft.displays=displays();draft.observedDigest="baseline";draft.discard();canvas.fit();wait(10);}
        function output(name){return draft.outputs.find(o=>o.name===name);}
        function card(name){return findChild(canvas,"display-card-"+name);}
        function test_click_any_monitor_selects_it(){mouseClick(card("B"),20,20);compare(draft.selectedKey,"B");mouseClick(card("C"),20,20);compare(draft.selectedKey,"C");}
        function test_centred_under_two_monitors(){draft.selectName("C");draft.centreGroup(true);compare(output("C").x,960);compare(output("C").y,1080);compare(draft.validationError,"");}
        function test_centred_above_and_negative_coordinates(){draft.selectName("C");draft.centreGroup(false);compare(output("C").x,960);compare(output("C").y,-1080);}
        function test_recovered_session_requires_explicit_review_and_preserves_edits(){
            draft.patch("C",{x:960,y:1080});const saved=draft.exported();saved.requiresReview=true;
            draft.discard();verify(draft.restore(saved));verify(draft.conflict);compare(output("C").x,960);
            const carried=draft.exported();verify(carried.requiresReview);draft.restore(carried);verify(draft.conflict);
            draft.rebase();verify(!draft.conflict);compare(output("C").y,1080);
        }
        function test_explicit_side_by_side_resolves_resized_overlap_and_undoes(){
            draft.patch("A",{mode:"3840x2160@60.00Hz",scale:1.25});
            draft.patch("C",{x:2880,y:1080});
            const before=JSON.stringify(draft.outputs);verify(draft.validationError.indexOf("Overlap:")===0);
            draft.arrangeSideBySide();compare(draft.validationError,"");compare(output("A").mode,"3840x2160@60.00Hz");compare(output("A").scale,1.25);
            compare(output("B").x,3072);compare(output("C").x,4992);compare(output("C").y,0);
            draft.undo();compare(JSON.stringify(draft.outputs),before);
        }
        function test_spacing_leaves_disabled_and_mirrored_outputs_unchanged(){
            draft.patch("B",{enabled:false});draft.patch("C",{mirrorOf:"A"});
            const disabled=JSON.stringify(output("B")),mirrored=JSON.stringify(output("C"));
            draft.arrangeSideBySide();compare(JSON.stringify(output("B")),disabled);compare(JSON.stringify(output("C")),mirrored);
        }
        function test_refresh_does_not_reset_draft(){draft.patch("C",{x:960,y:1080});for(let i=0;i<4;i++)draft.displays=displays();compare(output("C").x,960);compare(output("C").y,1080);verify(draft.dirty);verify(!draft.conflict);}
        function test_external_change_preserves_edits_and_requires_rebase(){draft.patch("C",{x:960,y:1080});draft.observedDigest="external";verify(draft.conflict);compare(output("C").y,1080);draft.rebase();verify(!draft.conflict);compare(draft.baseDigest,"external");}
        function test_same_logical_dimensions_same_preview(){compare(card("A").width,card("B").width);compare(card("A").height,card("B").height);}
        function test_current_refresh_precision(){compare(output("A").mode,"1920x1080@60.00Hz");}
        function test_mode_scale_and_rotation_change_logical_dimensions(){draft.patch("B",{mode:"1280x720@60.00Hz",scale:1.25,transform:1});const r=Geometry.rectangle(output("B"));compare(r.width,576);compare(r.height,1024);}
        function test_zoom_fit_do_not_change_world_geometry(){draft.patch("C",{x:-1000,y:1100});canvas.zoom(1.3);canvas.fit();compare(output("C").x,-1000);compare(output("C").y,1100);}
        function test_drag_does_not_destroy_card_or_snap_back_on_refresh(){
            const target=card("C"),start=target.mapToItem(canvas,20,20);canvas.snapping=false;
            mousePress(canvas,start.x,start.y,Qt.LeftButton);
            mouseMove(canvas,start.x-100,start.y+100,30);wait(10);
            verify(canvas.dragging);const x=output("C").x,y=output("C").y;verify(y>0);
            draft.displays=displays();wait(10);compare(card("C"),target);compare(output("C").x,x);compare(output("C").y,y);
            mouseRelease(canvas,start.x-100,start.y+100,Qt.LeftButton);verify(!canvas.dragging);
            compare(output("C").x,x);compare(output("C").y,y);
        }
        function test_keyboard_nudge_and_undo(){draft.selectName("C");card("C").forceActiveFocus();keyClick(Qt.Key_Down,Qt.ShiftModifier);compare(output("C").y,10);draft.undo();compare(output("C").y,0);}
        function test_hotplug_during_drag_reconciles_cards_on_release(){
            const target=card("C"),start=target.mapToItem(canvas,20,20);
            mousePress(canvas,start.x,start.y,Qt.LeftButton);mouseMove(canvas,start.x-80,start.y+80,30);verify(canvas.dragging);
            draft.displays=displays().filter(d=>d.name!=="C");verify(draft.selectedKey!=="C");
            mouseRelease(canvas,start.x-80,start.y+80,Qt.LeftButton);tryCompare(canvas,"dragging",false);wait(20);
            compare(canvas.cardModel.length,2);verify(!card("C"));
        }
        function test_selection_follows_identity_after_reorder_and_disconnect(){draft.selectName("B");draft.displays=displays().reverse();compare(draft.selectedKey,"B");draft.displays=displays().filter(d=>d.name!=="B");verify(draft.selectedKey!=="B");}
        function test_delayed_inventory_fits_all_detected_monitors(){
            draft.displays=[];draft.discard();canvas.fit();wait(10);
            draft.displays=displays();wait(30);
            for(const name of ["A","B","C"]){const c=card(name);verify(c.x>=0&&c.y>=0);verify(c.x+c.width<=canvas.width+1);verify(c.y+c.height<=canvas.height+1);}
        }
        function test_hotplug_refits_even_after_the_initial_camera_was_fitted(){
            const next=displays();next.push(Object.assign({},next[0],{key:"D",name:"D",x:-7000,y:-4000}));
            draft.displays=next;wait(30);const c=card("D");verify(c.x>=0&&c.y>=0);verify(c.x+c.width<=canvas.width+1);
        }
        function test_detected_geometry_does_not_silently_replace_a_dirty_baseline(){
            draft.patch("C",{y:1200});const next=displays();next[2].width=1280;next[2].height=720;
            draft.displays=next;draft.observedDigest="new-mode";
            compare(Geometry.rectangle(output("C")).width,1920);compare(output("C").y,1200);verify(draft.conflict);
            draft.rebase();compare(Geometry.rectangle(output("C")).width,1280);compare(output("C").y,1200);
        }
        function test_click_below_threshold_never_moves_a_display(){const c=card("B"),x=output("B").x;mousePress(c,20,20);mouseMove(c,22,22);mouseRelease(c,22,22);compare(output("B").x,x);}
        function test_projection_stage_undo_retains_prior_arrangement(){
            draft.patch("C",{y:1200});const next=draft.outputs.map(o=>Object.assign({},o,{enabled:o.key==="A"}));
            draft.stage({outputs:next,policyPatch:{projectionMode:"pc-only"}});verify(!output("B").enabled);
            draft.undo();verify(output("B").enabled);compare(output("C").y,1200);
        }
        function test_disabled_zero_geometry_uses_last_confirmed_mode_when_enabled(){
            const next=displays();next[2].disabled=true;next[2].width=0;next[2].height=0;next[2].refreshRate=0;next[2].restoreMode="1280x720@60.00Hz";
            draft.displays=next;compare(output("C").mode,"1280x720@60.00Hz");draft.patch("C",{enabled:true});compare(draft.validationError,"");
        }
        function test_new_monitor_is_fitted_even_while_an_old_draft_is_dirty(){
            draft.patch("C",{y:1300});const next=displays();next.push(Object.assign({},next[0],{key:"D",name:"D",x:-8000,y:-3000}));
            draft.displays=next;draft.observedDigest="hotplug";wait(30);
            compare(output("C").y,1300);verify(draft.conflict);const c=card("D");verify(c.x>=0&&c.x+c.width<=canvas.width+1);
        }
        function test_rebase_uses_new_connector_name_for_a_stable_display_identity(){
            draft.stage({outputs:draft.outputs,baseDigest:"baseline"});
            const next=displays();next[1].name="NEW-B";draft.displays=next;draft.observedDigest="new-connector";
            draft.rebase();compare(draft.outputs.find(o=>o.key==="B").name,"NEW-B");
            mouseClick(card("NEW-B"),20,20);compare(draft.selectedKey,"B");
        }
        function test_centre_snap_group(){const out=output("C"),snap=Geometry.snap(out,draft.outputs,958,1082,8);compare(snap.x,960);compare(snap.y,1080);}
    }
}
