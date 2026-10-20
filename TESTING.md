# HearAble — Manual Testing Checklist

Use a **real Android phone with a SIM card** unless a test says "emulator OK".
Only use emergency contacts who have **agreed** to receive test messages.

Fill in the **Result** column with ✅ (pass), ❌ (fail) or ⚠️ (partly), and add notes.

Tester: ____________________  Phone model / Android version: ____________________  Date: ____________

---

## 1. Registration and login

| ID | Steps | Expected result | Result |
|----|-------|-----------------|--------|
| A1 | Sign up with all fields valid, tick consent | Account created, "Verify your email" screen | |
| A2 | Sign up with empty fields | Red error under every required field | |
| A3 | Sign up with invalid email (`abc@`) | "Enter a valid email address" | |
| A4 | Password `abc12` / `onlyletters` | "Use at least 8 characters" / "Use both letters and numbers" | |
| A5 | Confirm password different | "Passwords do not match" | |
| A6 | Phone `12345` | Phone format error | |
| A7 | Emergency contact = your own number | "Use a different number from your own" | |
| A8 | Submit without ticking contact consent | "Please confirm this before continuing" | |
| A9 | Sign up with an email that already exists | "An account already exists with this email" | |
| A10 | Login with wrong password | "Incorrect email or password." | |
| A11 | Login before verifying email | Verify email screen, not dashboard | |
| A12 | Click verification link | App moves on automatically within ~5 s | |
| A13 | Forgot password | Neutral "If an account exists…" message, email arrives | |
| A14 | Close and reopen app while logged in | Goes straight to dashboard | |
| A15 | Log out | Confirmation, then Welcome screen | |

## 2. Permissions and consent

| ID | Steps | Expected result | Result |
|----|-------|-----------------|--------|
| P1 | First login after verification | Permissions & privacy screen with explanations | |
| P2 | Continue without agreeing | "Please agree before continuing" | |
| P3 | Deny microphone, continue | Warning dialog; dashboard shows mic row red | |
| P4 | Deny a permission twice | "Blocked — change in Settings", Open Settings works | |
| P5 | Return from phone Settings after allowing | Status updates automatically | |

## 3. Emergency contacts

| ID | Steps | Expected result | Result |
|----|-------|-----------------|--------|
| C1 | Add second contact without consent tick | "Please confirm this before saving" | |
| C2 | Add duplicate number | "This number is already one of your contacts" | |
| C3 | Set second contact as primary | Roles swap | |
| C4 | Delete primary | Second contact promoted to primary | |
| C5 | Delete last personal contact | Strong warning dialog, red "No emergency contact" banner | |
| C6 | Send test SMS | Sending → Sent → Delivered ✓ (or "delivery not confirmed") | |
| C7 | Send test SMS in airplane mode | "Test SMS failed" with reason | |

## 4. Sound detection (real sounds — play recordings from another device)

| ID | Steps | Expected result | Result |
|----|-------|-----------------|--------|
| S1 | Start monitoring | "Monitoring active", "HearAble is listening" notification | |
| S2 | Talk near phone | Live card shows "Speech" | |
| S3 | Doorbell recording | Doorbell alert (Tier 1), nobody contacted | |
| S4 | Car horn recording | Vehicle horn alert | |
| S5 | Smoke alarm recording **< 2 s** | **No** smoke alert (needs 3 of last 4 frames) | |
| S6 | Smoke alarm recording **≥ 3 s** | Smoke alarm emergency screen, 30 s countdown | |
| S7 | Glass breaking recording | Glass-breaking emergency screen | |
| S8 | Clap / slam a book | Loud-bang check-in, 60 s countdown | |
| S9 | Same sound repeated within cooldown | No duplicate alert | |
| S10 | Music / TV playing for 2 minutes | Note any false positives: __________ | |
| S11 | Phone in a pocket / 5 m away | Note whether detection still works: __________ | |

## 5. Emergency workflow

| ID | Steps | Expected result | Result |
|----|-------|-----------------|--------|
| E1 | Smoke alert → "I'm safe" | Closes, history "User confirmed safe" | |
| E2 | Same smoke sound again within 2 min | Suppressed (no new alert) | |
| E3 | Smoke alert → wait 30 s | Escalation, siren, SMS to every contact | |
| E4 | Loud bang → "I need help" | Immediate escalation, SMS says "asked for help" | |
| E5 | Loud bang → no response 60 s | Escalation | |
| E6 | Loud bang → Ignore → reason + 5 min | History shows reason + mute | |
| E7 | During the 5-min mute: loud bang | **No** alert | |
| E8 | During the 5-min mute: smoke alarm | Smoke alert **still appears** | |
| E9 | During loud-bang countdown: smoke alarm | Bang screen replaced by smoke screen | |
| E10 | Back button on emergency screen | Does nothing | |
| E11 | Escalation → "I'm safe — cancel" | "I am safe" SMS sent to reached contacts | |
| E12 | Escalation in airplane mode | "Failed", red summary, Retry works after reconnecting | |
| E13 | 4 real escalations within 30 min | 4th shows "too many alerts" (rate limit) | |
| E14 | Simulated smoke → wait | "Simulated test — not sent", **no SMS** | |

## 6. Background monitoring

| ID | Steps | Expected result | Result |
|----|-------|-----------------|--------|
| B1 | Monitoring on → Home button → doorbell | Heads-up notification | |
| B2 | Screen locked → smoke alarm ≥ 3 s | Screen wakes, countdown over lock screen | |
| B3 | Screen locked → let countdown expire | SMS sent | |
| B4 | Open app normally while locked | PIN required (no lock-screen bypass) | |
| B5 | Swipe app away from recents | "HearAble monitoring stopped" notification | |
| B6 | Revoke mic in Settings while monitoring | Monitoring stopped, honest message | |
| B7 | Leave monitoring on for 1 hour, screen off | Still listening? Battery used: ____ % | |

## 7. History, settings, profile

| ID | Steps | Expected result | Result |
|----|-------|-----------------|--------|
| H1 | History filters (type + date) | Correct events shown | |
| H2 | Escalated event details | Response, reason, per-contact SMS status | |
| H3 | Delete one event / delete all | Removed from list and Firestore | |
| T1 | Turn Doorbell off → doorbell sound | No alert | |
| T2 | Smoke/glass switches | Locked on | |
| T3 | Countdown slider 20 s → simulate smoke | Countdown starts at 20 | |
| T4 | Flashlight / alarm off | Effect not used, visual alert still shown | |
| R1 | Edit name and phone | Saved, dashboard updated | |
| R2 | Delete account (test account) wrong password | Error, nothing deleted | |
| R3 | Delete account correct password | Data and login removed in Firebase | |

## 8. Offline and restart

| ID | Steps | Expected result | Result |
|----|-------|-----------------|--------|
| O1 | Airplane mode → simulated alerts → reconnect | Events appear in Firestore after reconnecting | |
| O2 | Airplane mode → detection still works | Yes (on-device model) | |
| O3 | Restart phone, open app | Logged in; monitoring **paused** until started again | |

## 9. Security

| ID | Steps | Expected result | Result |
|----|-------|-----------------|--------|
| X1 | Firebase Rules Playground: read another user's document | **Denied** | |
| X2 | Rules Playground: create contact with phone `12345` | **Denied** | |
| X3 | Rules Playground: change `simulated` on an existing event | **Denied** | |

## 10. Accessibility

| ID | Steps | Expected result | Result |
|----|-------|-----------------|--------|
| Y1 | Turn on TalkBack, go through dashboard | Every button and status is read out | |
| Y2 | Phone font size: largest | No text cut off on alert screens | |
| Y3 | Every alert works with phone on silent | Yes — visual + vibration only | |

---

## Known limitations (record honestly in your report)

- Detection may fail if the phone is far away, covered, in a pocket, or in a noisy place.
- Model scores are estimates, not probabilities. Thresholds need tuning with more real recordings.
- Monitoring stops if the app is swiped away or the phone is restarted.
- Some phone brands (Xiaomi, Oppo, Vivo, Huawei) may stop background apps unless battery settings are changed.
- SMS uses the user's own SIM; delivery depends on signal and credit. Some networks never confirm delivery.
- iPhone: no automatic SMS (Messages opens pre-filled); background monitoring not yet implemented.
