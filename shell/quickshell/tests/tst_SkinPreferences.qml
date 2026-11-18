import QtQuick
import QtTest
import "../config/SkinPreferences.js" as Preferences

TestCase {
    name: "SkinPreferences"
    function fixture() {
        return {schemaVersion:1,defaultMode:"native",frames:{},backgrounds:{calendar:{source:"",scaling:"crop",imageOpacity:1,scrimOpacity:0},tray:{source:"keep.png",scaling:"fit"}},persona:{railTextPx:12},unrelated:{keep:true}};
    }
    function test_scoped_merge_preserves_unrelated_values() {
        const original=fixture();
        const next=Preferences.merge(original,"calendar",{source:"image.png",scaling:"fit",imageOpacity:.8,scrimOpacity:.2},{railTextPx:14,reducedMotion:true,hoverExpansionEnabled:false});
        compare(original.backgrounds.calendar.source,"");
        compare(next.backgrounds.calendar.source,"image.png");
        compare(next.backgrounds.tray.source,"keep.png");
        verify(next.unrelated.keep);
        compare(next.persona.railTextPx,14);
    }
    function test_readability_preferences() {
        const next=Preferences.merge(fixture(),"calendar",{},{uiTextScale:1.5,highContrast:true});
        compare(next.persona.uiTextScale,1.5);verify(next.persona.highContrast);compare(next.persona.railTextPx,12);
    }
    function test_invalid_and_unknown_refused() {
        const calls=[()=>Preferences.merge(fixture(),"missing",{},{}),()=>Preferences.merge(fixture(),"calendar",{imageOpacity:2},{}),()=>Preferences.merge(fixture(),"calendar",{},{railTextPx:99}),()=>Preferences.merge(fixture(),"calendar",{},{uiTextScale:2}),()=>Preferences.merge(fixture(),"calendar",{},{highContrast:"yes"})];
        for(const call of calls) {
            let rejected=false;
            try { call(); } catch(e) { rejected=true; }
            verify(rejected);
        }
    }
}
