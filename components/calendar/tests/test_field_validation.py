import tempfile,unittest
from senomy_calendar.engine import Engine,FieldErrors

class FieldValidationTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.engine=Engine(self.temp.name)
    def tearDown(self):
        self.engine.store.db.close();self.temp.cleanup()
    def form(self,**fields):
        result=dict(source="personal",title="Meeting",start="2026-10-15T09:00",end="2026-10-15T10:00",timezone="UTC",frequency="NONE",reminder="10");result.update(fields);return result
    def test_invalid_fields_are_aggregated_without_writing_or_discarding_draft(self):
        form=self.form(title="",start="2026-02-31T09:00",end="invalid",timezone="Invalid/Timezone",reminder="1 week before",url="javascript:alert(1)")
        self.engine.draft_save(form)
        with self.assertRaises(FieldErrors) as error:self.engine.save(form,"invalid")
        self.assertTrue({"title","start","end","timezone","reminder","url"}<=set(error.exception.fields))
        self.assertEqual(self.engine.snapshot()["eventCount"],0)
        self.assertEqual(self.engine.draft_get(),form)
    def test_dst_time_points_to_exact_field(self):
        with self.assertRaises(FieldErrors) as error:self.engine.save(self.form(start="2026-03-29T01:30",end="2026-03-29T03:00",timezone="Europe/London"),"dst")
        self.assertIn("startTime",error.exception.fields)
        self.assertIn("daylight",error.exception.fields["startTime"])
    def test_preferences_atomic_validation_and_persistent_formats(self):
        initial=self.engine.preferences()
        with self.assertRaises(FieldErrors) as error:self.engine.prefs_save(dict(dateFormat="uk",workStart="25:00",workEnd="bad",timezone="Invalid/Timezone",defaultReminder="many"))
        self.assertTrue({"dateFormat","workStart","workEnd","timezone","defaultReminder"}<=set(error.exception.fields))
        self.assertEqual(self.engine.preferences(),initial)
        for region in ("eu","us","iso"):self.assertEqual(self.engine.prefs_save({"dateFormat":region})["dateFormat"],region)
        self.engine.store.db.close();self.engine=Engine(self.temp.name)
        self.assertEqual(self.engine.preferences()["dateFormat"],"iso")
    def test_numeric_repeat_errors_and_valid_custom_units_contract(self):
        with self.assertRaises(FieldErrors) as error:self.engine.save(self.form(frequency="WEEKLY",interval="x",count="2",until="2026-10-10"),"repeat")
        self.assertTrue({"interval","until"}<=set(error.exception.fields))
        saved=self.engine.save(self.form(reminder="2880"),"two-days")
        self.assertEqual(self.engine.detail("personal",saved["uid"])["reminder"],"2880")

    def test_unchanged_imported_alarm_after_start_is_preserved(self):
        from datetime import timedelta
        import icalendar
        old=icalendar.Event();alarm=icalendar.Alarm();alarm.add('action','DISPLAY');alarm.add('trigger',timedelta(minutes=10));old.add_component(alarm)
        event=self.engine.build_event(self.form(reminder='-10'),'imported',old=old)
        self.assertEqual(event.walk('VALARM')[0].decoded('TRIGGER'),timedelta(minutes=10))
        with self.assertRaises(FieldErrors):self.engine.build_event(self.form(reminder='-15'),'imported',old=old)
