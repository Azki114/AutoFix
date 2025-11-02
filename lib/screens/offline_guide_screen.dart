// lib/screens/offline_guide_screen.dart
import 'package:flutter/material.dart';
import 'package:autofix/main.dart' as app_nav;
import 'package:autofix/screens/guide_viewer_screen.dart'; // Ensure this import is correct

class OfflineGuideScreen extends StatelessWidget {
  const OfflineGuideScreen({super.key});

  // Define your Markdown content as a multiline string here
  static const String _engineStartingGuideContent = '''
# Engine Starting Issues Troubleshooting

## 1. Check the Battery
* **Lights/Dashboard:** Do the dashboard lights come on brightly? Do the headlights work?
    * **No/Dim Lights:** Vehicle battery is likely dead or very low.
        * **Solution:** Try jump-starting your vehicle. If it starts, get the battery and charging system checked.
    * **Lights are bright:** Battery might be okay, but still check terminals.
* **Battery Terminals:** Are the battery terminals clean and tight? Loose or corroded terminals can prevent power flow.
    * **Solution:** Clean corrosion with a wire brush and baking soda/water mixture. Tighten connections.

## 2. Listen to the Sound
* **Clicking Sound:** A rapid clicking sound when you turn the key (or press start) usually indicates a low battery or a faulty starter solenoid.
    * **Solution:** Jump-start (if battery is low). If it persists, check starter motor.
* **No Sound at all:** Could be a completely dead battery, faulty ignition switch, or a major electrical issue.
    * **Solution:** Check battery voltage with a multimeter. Inspect fuses.
* **Engine Cranks but Doesn't Start:** This means the battery and starter are working, but there's no combustion.
    * **Possible Causes:** Lack of fuel, spark, or air.
    * **Solution:** Check fuel level, listen for fuel pump prime, check spark plugs (if applicable), inspect air filter.

## 3. Check Fuel Level
* Is there enough fuel in the tank? A faulty fuel gauge can sometimes be misleading.

## 4. Inspect Spark Plugs (Gasoline Engines)
* Are the spark plugs fouled, worn, or wet with fuel? This can prevent proper ignition. (Applicable to most gasoline vehicles, including motorcycles).

## 5. Check Fuses
* A blown fuse in the ignition or fuel pump circuit can prevent the vehicle from starting. Consult your vehicle's manual for fuse box locations.

## When to Call a Mechanic
If you've tried these basic steps and your vehicle still won't start, it's best to call a professional mechanic. The issue could be more complex, involving the starter motor, alternator, fuel pump, or engine control unit (ECU).
''';
  static const String _flatTireGuideContent = '''

# Flat Tire Changing Guide

Changing a flat tire can seem daunting, but with the right tools and steps, it's a manageable task for most vehicles.

## Tools You'll Need:
* **Spare Tire:** Ensure it's properly inflated.
* **Jack:** To lift the vehicle.
* **Lug Wrench:** To loosen and tighten lug nuts.
* **Vehicle Owner's Manual:** For specific jacking points and torque specs.
* **Optional but Recommended:**
    * Gloves
    * Flashlight (if dark)
    * Wheel wedges/chocks (to prevent rolling)
    * Small piece of wood (for soft ground under the jack)

## Steps to Change a Flat Tire:

### 1. Find a Safe Location
* Pull over to a flat, stable, and safe area away from traffic. Avoid hills or soft ground.
* Turn on your hazard lights.
* If possible, set up reflective triangles or flares behind your vehicle.

### 2. Prepare the Vehicle
* Engage the parking brake (or emergency brake).
* If your vehicle is a manual transmission, put it in first or reverse gear. For automatic, put it in "Park" (P).
* If you have wheel wedges/chocks, place them in front of and behind the tire diagonally opposite to the flat tire (e.g., if front-right is flat, chock the rear-left).

### 3. Access Tools and Spare
* Locate your spare tire, jack, and lug wrench. These are usually in the trunk (cars) or under the seat/in a compartment (some motorcycles/scooters).

### 4. Loosen the Lug Nuts
* Before jacking up the vehicle, use the lug wrench to loosen the lug nuts on the flat tire. Turn counter-clockwise. You may need to use significant force, even standing on the wrench if safe.
* Only loosen them about a quarter to half a turn; don't remove them yet.

### 5. Position the Jack
* Consult your vehicle's owner's manual to find the correct jacking points. Using the wrong spot can damage your vehicle or cause the jack to slip.
* Place the jack directly under the designated jacking point near the flat tire.
* Slowly raise the vehicle until the flat tire is just off the ground. Ensure the vehicle is stable on the jack.

### 6. Remove the Lug Nuts and Flat Tire
* Once the tire is off the ground, fully unscrew the lug nuts by hand.
* Carefully pull the flat tire straight off the wheel studs.

### 7. Mount the Spare Tire
* Align the spare tire with the wheel studs.
* Push the spare tire onto the studs until it's flush with the hub.
* Hand-tighten the lug nuts onto the studs.

### 8. Lower the Vehicle and Tighten Lug Nuts
* Slowly lower the vehicle until the spare tire makes contact with the ground but the full weight is not on it yet.
* Using the lug wrench, tighten the lug nuts in a star pattern (criss-cross) to ensure even tightening. This is crucial to prevent the wheel from wobbling.
* Lower the vehicle completely to the ground and remove the jack.
* Give the lug nuts one final, firm tighten in the star pattern.

### 9. Store the Flat Tire and Tools
* Place the flat tire in the location where the spare was stored.
* Gather all your tools (jack, lug wrench, wedges) and store them securely.

### 10. Check Spare Tire Pressure and Get Professional Help
* Drive cautiously to the nearest service station or mechanic.
* Have the pressure of your spare tire checked immediately. Spare tires (especially "donut" spares) often have higher pressure requirements and are for temporary use only.
* Get your flat tire repaired or replaced as soon as possible.

Remember, safety is paramount. If you are unsure at any point, it's always best to call for roadside assistance.
''';
  static const String _batteryDiagnosisGuideContent = '''
# Battery Problems Diagnosis
# 🔋 Battery Diagnostic Guide (Motorcycles & Four-Wheeled Vehicles)

This guide will walk you through the essential steps to properly diagnose a vehicle battery—whether it's in a motorcycle or a four-wheeled vehicle. Understanding how to test and evaluate battery health can save you time, money, and prevent breakdowns.

---

## 🧰 Tools Required

- Multimeter (Digital or Analog)
- Battery Charger (Optional but useful)
- Safety Gloves & Goggles
- Wire Brush or Terminal Cleaner
- Hydrometer (For lead-acid batteries)
- Load Tester (Optional)

---

## ⚠️ Safety First

- Work in a well-ventilated area.
- Always wear protective gear.
- Remove metal accessories (rings, watches).
- Ensure the vehicle is off before starting diagnostics.

---

## 🗂 Battery Types

| Type          | Common Vehicles     | Maintenance |
|---------------|---------------------|-------------|
| Lead-Acid     | Most cars, motorcycles | Medium      |
| AGM (Absorbed Glass Mat) | Cars, motorcycles | Low         |
| Lithium-Ion   | Modern motorcycles  | Very Low    |

---

## 🔎 Step-by-Step Battery Diagnostic

### 1. **Visual Inspection**
- **Check for:**
  - Corroded terminals
  - Bulging or cracked casing
  - Leaks or discharge
  - Loose battery mounts

> Clean terminals with a wire brush if corroded.

---

### 2. **Battery Voltage Test**

#### ✅ Procedure:
1. Set multimeter to **DC Voltage** (20V range).
2. Connect red probe to the **positive (+)** terminal.
3. Connect black probe to the **negative (-)** terminal.

#### 🔢 Voltage Reference Table:

| Voltage Reading | Battery Status     |
|-----------------|--------------------|
| 12.6V – 12.8V   | Fully Charged      |
| 12.4V – 12.6V   | 75% Charged        |
| 12.2V – 12.4V   | 50% Charged        |
| 12.0V – 12.2V   | 25% Charged        |
| < 12.0V         | Discharged/Dead    |

> Motorcycle batteries typically read lower (12.5V full).

---

### 3. **Load Test** *(Optional)*

Use a battery load tester or vehicle’s starter system to simulate a load.

- Crank the engine while observing voltage:
  - Should not drop below **9.6V** (for cars)
  - Should not drop below **9.0V** (for motorcycles)

> A voltage drop below these indicates a weak battery.

---

### 4. **Charging Test (Alternator Output)**

#### ✅ Procedure:
1. Start the engine.
2. Re-check voltage at the terminals.

#### 🔢 Ideal Charging Voltage:
- **13.8V – 14.7V** for both motorcycles and cars

> If below 13.5V or above 15V, the alternator or voltage regulator may be faulty.

---

### 5. **Hydrometer Test** *(Lead-Acid Only)*

- Draw battery fluid into the hydrometer.
- Read the specific gravity:
  - **1.265 or above** – Fully Charged
  - **1.200 - 1.265** – Undercharged
  - **Below 1.200** – Discharged or Bad Cell

> Low fluid or varying cell readings suggest replacement.

---

## 🧼 Maintenance Tips

- Check electrolyte levels monthly (for lead-acid).
- Clean terminals regularly.
- Ensure tight connections.
- Avoid short rides that don't fully recharge the battery.
- Use a trickle charger for seasonal storage.

---

## 🧾 When to Replace the Battery?

- Cranking is consistently weak.
- Voltage drops rapidly after charging.
- Battery is more than 3–5 years old.
- Swelling or leaking case.
- Failed load or hydrometer test.

---

## 🚗 Differences: Motorcycle vs. Car Batteries

| Feature           | Motorcycle Battery | Car Battery       |
|-------------------|--------------------|-------------------|
| Size              | Smaller            | Larger            |
| Cold Crank Amps   | Lower (100–300 CCA)| Higher (400–900 CCA) |
| Charging System   | Simpler            | More Powerful     |
| Lifespan          | 2–4 years          | 3–6 years         |

---

## ✅ Summary Checklist

- [ ] Visual inspection done
- [ ] Voltage checked (resting & charging)
- [ ] Load tested (if applicable)
- [ ] Hydrometer test (if applicable)
- [ ] Charging system checked
- [ ] Maintenance actions performed

''';
  static const String _brakeInspectionGuideContent = '''
# Brake System Inspection Guide

# 🛑 Brake Inspection Guide (Motorcycles & Four-Wheeled Vehicles)

Regular brake inspection is critical for rider and driver safety. This guide outlines how to inspect and assess the condition of braking systems in motorcycles and cars.

---

## 🧰 Tools Required

- Flashlight
- Tire iron or socket wrench
- Jack and jack stands (for cars)
- Allen keys or wrenches (for motorcycles)
- Caliper tool (for measuring pad thickness)
- Brake fluid tester (optional)
- Gloves & eye protection

---

## ⚠️ Safety First

- Work on a level surface.
- Use wheel chocks to prevent rolling.
- Ensure the vehicle is off, and wheels are cool before inspection.
- Never touch brake rotors right after driving—they may be hot.

---

## 🔍 Brake System Components

| Component         | Motorcycle                 | Four-Wheeled Vehicle         |
|-------------------|----------------------------|------------------------------|
| Brake Pads        | Front and rear disc pads   | Front and rear disc/drum pads|
| Brake Discs       | Front and sometimes rear   | All four wheels (usually)    |
| Brake Lines       | Rubber or braided steel    | Rubber or steel hard lines   |
| Master Cylinder   | Usually on handlebars      | Near driver’s side firewall  |
| Brake Fluid       | DOT 3, 4, or 5.1 fluid     | Same as motorcycle           |

---

## ✅ Step-by-Step Inspection

### 1. **Visual Inspection**

#### 🚦 Check:
- Brake pads (thickness, wear pattern)
- Brake discs/rotors (warping, grooves, rust)
- Brake fluid (level and color)
- Brake lines (cracks, leaks, bulges)

> **Minimum pad thickness:**
> - Motorcycle: **2-3 mm**
> - Car: **3 mm** or more

---

### 2. **Brake Pad Inspection**

#### Motorcycle:
- Remove caliper if needed.
- Check both pads for even wear.
- Replace if:
  - Below minimum thickness
  - Uneven wear
  - Contaminated with oil/grease

#### Car:
- Jack up the car, remove wheels.
- Look through caliper window or remove caliper.
- Replace if:
  - Squealing noise
  - Less than 3 mm pad thickness
  - Vibration when braking

---

### 3. **Rotor/Disc Inspection**

- Look for:
  - Deep grooves or scoring
  - Warping (feel pulsing when braking)
  - Rust (especially around edges)
  - Minimum thickness (check service manual)

> **Tip:** Run your finger (carefully) along the edge of the disc for a lip.

---

### 4. **Brake Fluid Check**

- Locate reservoir:
  - Motorcycle: near handlebars or rear brake pedal
  - Car: near driver-side engine bay

- Check:
  - Fluid level between MIN and MAX
  - Fluid color (should be clear or light amber)

> **Replace fluid** if:
> - Dark brown/black color
> - Spongy brake feel
> - Last changed over 2 years ago

---

### 5. **Brake Line & Master Cylinder Check**

- Look for:
  - Cracked rubber lines
  - Fluid leaks at connectors
  - Loose fittings or worn grommets

- For motorcycles, ensure the brake lever/pedal doesn’t feel too soft or too stiff.

---

### 6. **Brake Test (Static & Road)**

#### Static Test:
- Press brake lever or pedal.
- Should feel firm, not spongy.
- No delay in response.

#### Road Test:
- Conduct in a safe, clear area.
- Apply brakes slowly, then harder.
- Watch for:
  - Pulling to one side
  - Vibration or noise
  - Extended stopping distance

---

## 🧼 Maintenance Tips

- Clean calipers and rotors regularly.
- Use brake cleaner spray—not water or soap.
- Replace pads before they wear too thin.
- Bleed brakes annually or every 2 years.
- Torque bolts to spec after reassembly.

---

## 🚗 Motorcycle vs. Car Differences

| Feature           | Motorcycle           | Four-Wheeled Vehicle      |
|-------------------|------------------------|---------------------------|
| Brake Setup       | Independent front/rear | Hydraulic system w/ABS    |
| Fluid Access      | Small master cylinders | Larger reservoir under hood |
| Pad Wear          | Faster in front        | Even wear (front > rear)  |
| Disc Size         | Smaller rotors         | Larger, ventilated rotors |

---

## ✅ Summary Checklist

- [ ] Brake pads checked (thickness, even wear)
- [ ] Rotors inspected (no warping/grooves)
- [ ] Brake fluid clean and full
- [ ] Brake lines intact
- [ ] Road test passed (no noise, vibration, pull)

---

## 📚 Additional Resources

- [NHTSA Brake Safety Tips](https://www.nhtsa.gov)
- [Motorcycle Brake Maintenance (RevZilla)](https://www.revzilla.com/)
- [Car Brake System Guide (Haynes Manuals)](https://haynes.com)

---

*Prepared by: [Your Name or Organization]*
*Date: 2025-07-28*


''';
  static const String _oilChangeGuideContent = '''
# Oil Change Procedure

# 🛢 Oil Change Guide (Motorcycles & Four-Wheeled Vehicles)

Regular oil changes are essential to maintain engine performance and longevity. This guide walks you through how to properly change engine oil for both motorcycles and cars.

---

## 🧰 Tools & Materials Needed

- Engine oil (check owner's manual for type/grade)
- New oil filter
- Oil filter wrench
- Socket wrench set
- Drain pan
- Funnel
- Gloves & rags
- Jack and jack stands (for cars)
- Crush washer or gasket (if needed)
- Service manual (optional but helpful)

---

## ⚠️ Safety Precautions

- Ensure the engine is **off** and has **cooled down slightly** (warm oil drains better, but don’t work on a hot engine).
- Use jack stands (not just the jack) when working under a car.
- Dispose of used oil and filters properly at a recycling center.

---

## 📋 Pre-Check

- Confirm oil **type** (e.g. SAE 10W-40) and **capacity** in the vehicle’s manual.
- Identify:
  - Drain plug location
  - Oil filter location
  - Oil fill cap

---

## 🔧 Oil Change Procedure

### 1. **Warm Up the Engine**
- Let the engine run for 2–3 minutes to warm the oil slightly.
- This helps it flow out more easily.

---

### 2. **Drain the Old Oil**

#### Motorcycle:
1. Put the bike on a center or paddock stand.
2. Place the oil drain pan under the drain bolt.
3. Use a wrench to remove the **drain plug**.
4. Let all the oil drain completely.

#### Car:
1. Jack up the car and place it on jack stands.
2. Position the oil drain pan under the oil pan.
3. Remove the **drain plug** with a socket wrench.
4. Let oil drain for several minutes.

> 🔁 Replace the **crush washer** if needed before re-tightening the drain plug.

---

### 3. **Remove and Replace the Oil Filter**

- Use an **oil filter wrench** to loosen the old filter.
- Let residual oil drain from the filter.
- Apply a thin layer of **new oil to the gasket** of the new filter.
- Install the new filter **hand-tight only** (don’t overtighten).

---

### 4. **Add New Oil**

- Use a **funnel** to pour oil into the fill port.
- Pour slowly and check the level using the **dipstick** or **inspection window** (for motorcycles).

#### Fill Quantities (General Estimates):
| Vehicle Type    | Engine Size    | Oil Volume      |
|-----------------|----------------|-----------------|
| Small Motorcycle| ~125–250cc     | 1.0 – 1.5 liters|
| Mid Motorcycle  | ~400–650cc     | 2.0 – 3.0 liters|
| Large Motorcycle| ~750–1000cc+   | 3.5 – 4.5 liters|
| Car (small)     | ~1.0–1.6L      | 3.5 – 4.0 liters|
| Car (mid/full)  | ~1.8–3.5L+     | 4.0 – 6.0 liters|

---

### 5. **Start Engine and Check for Leaks**

- Start the engine for 30–60 seconds.
- Turn off and wait a few minutes.
- Check under the vehicle for leaks around the **drain plug** and **oil filter**.

---

### 6. **Recheck Oil Level**

- After a few minutes, check oil level again:
  - Add more if low.
  - Do not overfill.

---

### 7. **Dispose of Used Oil Properly**

- Pour used oil into a sealed container.
- Take it to a recycling center, auto parts store, or local disposal station.

---

## 🧼 Maintenance Tips

- Change oil **every 3,000–5,000 km** (or 2,000–3,000 mi) for motorcycles.
- Cars often need oil changes every **5,000–10,000 km** depending on usage and oil type.
- Always change the oil filter when changing oil.
- Use full synthetic oil for better engine protection (if compatible).

---

## 🧾 Oil Change Interval Reference

| Vehicle Type    | Oil Type         | Recommended Interval        |
|-----------------|------------------|-----------------------------|
| Motorcycle      | Mineral          | 3,000 km / 2,000 mi         |
| Motorcycle      | Semi-Synthetic   | 5,000 km / 3,000 mi         |
| Motorcycle      | Full Synthetic   | 6,000–8,000 km / 4,000–5,000 mi |
| Car (Gasoline)  | Conventional     | 5,000 km / 3,000 mi         |
| Car (Synthetic) | Full Synthetic   | 8,000–12,000 km / 5,000–7,500 mi |

---

## ✅ Summary Checklist

- [ ] Warmed engine before draining
- [ ] Oil fully drained
- [ ] Filter replaced and gasket oiled
- [ ] Drain plug reinstalled with washer
- [ ] New oil added to correct level
- [ ] Engine tested and no leaks found
- [ ] Old oil and filter properly disposed

---

## 📚 Additional Resources

- [Oil Viscosity Explained (Mobil1)](https://mobiloil.com)
- [Motorcycle Oil Change Guide (RevZilla)](https://www.revzilla.com)
- [Car Oil Change Basics (Valvoline)](https://www.valvoline.com)

---

*Prepared by: [Your Name or Organization]*
*Date: 2025-07-28*


''';
  static const String _overheatingEngineGuideContent = '''
# Overheating Engine Troubleshooting

# 🌡️ Overheating Diagnostic & Prevention Guide (Motorcycles & Four-Wheeled Vehicles)

Engine overheating can cause serious and costly damage. This guide will help you diagnose, troubleshoot, and prevent overheating issues in both motorcycles and cars.

---

## 🧰 Tools You Might Need

- Flashlight
- OBD2 scanner (for cars)
- Infrared thermometer (optional)
- Coolant tester or hydrometer
- Funnel
- Coolant reservoir pressure tester
- Gloves & eye protection

---

## ⚠️ Symptoms of Overheating

| Symptom                               | Common in Cars | Common in Motorcycles |
|-------------------------------------|----------------|------------------------|
| Rising temperature gauge            | ✅             | ✅                     |
| Coolant boiling or steaming         | ✅             | ✅                     |
| Engine knocking or loss of power    | ✅             | ✅                     |
| Coolant smell or leaks              | ✅             | ✅                     |
| Radiator fan constantly running     | ✅             | ✅                     |
| Warning lights on dashboard         | ✅             | ❌ (depends on model)  |

---

## 🧪 Step-by-Step Diagnostic Process

### 1. **Check Coolant Level**

- Inspect the **radiator cap** and **coolant reservoir**.
- If low, top up with proper coolant mix.
- Do **not** open the radiator cap when hot!

> Motorcycles often have a smaller cooling system, so even small coolant losses can cause overheating.

---

### 2. **Inspect Radiator and Hoses**

- Look for:
  - Leaks
  - Cracked hoses
  - Clogged or dirty fins
- Use a flashlight to check airflow through the radiator.

> Blocked airflow (due to dirt, mud, or bugs) can cause overheating.

---

### 3. **Check Radiator Fan Operation**

#### Cars:
- Fan should activate when engine gets hot (usually above 90°C / 194°F).
- Use an OBD2 scanner or temperature sensor to verify.

#### Motorcycles:
- Most modern motorcycles have electric fans triggered by a sensor.
- Listen for the fan when stationary or idling after warming up.

> If the fan doesn’t spin, test the **relay**, **fuse**, or **temperature switch**.

---

### 4. **Inspect Thermostat (Car-specific)**

- Thermostat regulates coolant flow.
- If stuck **closed**, it prevents coolant from circulating and causes overheating.

> A faulty thermostat should be **replaced**, not repaired.

---

### 5. **Coolant Quality Check**

- Old or contaminated coolant reduces heat dissipation.
- Use a coolant tester to check freeze/boil point.
- If coolant is brown, rusty, or sludgy: **flush the system**.

---

### 6. **Water Pump Functionality**

- Look for:
  - Coolant leaks around the pump
  - Squealing or grinding noise
  - Engine temperature rising despite full coolant

> The water pump is essential for circulating coolant—replace if faulty.

---

### 7. **Check Oil Level and Condition**

- Low oil = increased engine friction = overheating.
- Milky oil may indicate a **blown head gasket**, allowing coolant and oil to mix.

---

### 8. **Look for Signs of a Blown Head Gasket**

| Symptom                   | Indicates |
|--------------------------|-----------|
| White smoke from exhaust | Coolant in combustion |
| Bubbles in coolant tank  | Combustion gases in coolant |
| Rapid coolant loss       | Internal leak |
| Milky oil                | Coolant in oil |

> A compression test or chemical test can confirm head gasket failure.

---

## 🛠 Immediate Actions if Overheating Happens

1. **Pull over safely** and turn off the engine.
2. **Do not open the radiator cap** until the engine cools (~30 minutes).
3. Turn on the heater in a car to help dissipate heat (if still running).
4. Add coolant or water temporarily (only when engine is cool).

---

## 🧼 Preventive Maintenance

| Task                      | Frequency           |
|-----------------------------|---------------------|
| Coolant level check         | Weekly or before rides |
| Full coolant flush          | Every 2 years or per manual |
| Radiator cleaning (external)| Monthly             |
| Thermostat and fan test     | Annually            |
| Oil and filter change


''';
  // New Markdown content for Basic Engine Check
  static const String _basicEngineCheckContent = '''
# Basic Engine Check Guide

Regularly checking your vehicle's engine is crucial for its longevity and your safety. This guide provides fundamental steps for a quick and effective basic engine inspection.

---

## 1. **Check Engine Oil Level**
* **Location:** Locate the dipstick, usually with a brightly colored handle.
* **Procedure:** Pull out the dipstick, wipe it clean, reinsert it fully, then pull it out again.
* **Reading:** The oil level should be between the 'MIN' and 'MAX' marks.
* **Action:** If low, add the appropriate type of oil as specified in your owner's manual.
  * 
---

## 2. **Check Coolant Level**
* **Location:** Find the coolant reservoir (often clear plastic, with 'MIN' and 'MAX' lines).
* **Procedure:** **Ensure the engine is cool** before opening any caps. The level should be between the marks.
* **Action:** If low, add a 50/50 mix of coolant and distilled water (or pre-mixed coolant) to the 'MAX' line.
  * 
---

## 3. **Inspect Brake Fluid Level**
* **Location:** The brake fluid reservoir is typically a small, clear plastic container near the master cylinder (often on the driver's side).
* **Procedure:** The fluid level should be between the 'MIN' and 'MAX' marks.
* **Action:** If low, top up with the correct DOT-specified brake fluid. A consistently low level might indicate a leak or worn brake pads.
  * 
---

## 4. **Check Power Steering Fluid (if applicable)**
* **Location:** Look for a reservoir with a cap often labeled 'Power Steering'.
* **Procedure:** Check the level using the dipstick attached to the cap or the marks on the reservoir.
* **Action:** Top up if necessary with the recommended power steering fluid.

---

## 5. **Inspect Washer Fluid**
* **Location:** The washer fluid reservoir is usually a large plastic container, often with a windshield icon on the cap.
* **Procedure:** Simply visually check the level.
* **Action:** Refill with windshield washer fluid as needed.

---

## 6. **Battery Terminals**
* **Visual Check:** Look for any corrosion (white or bluish powdery substance) on the battery terminals.
* **Connections:** Ensure the cables are tightly connected to the terminals. Loose or corroded connections can prevent proper starting.
  * 
---

## 7. **Hoses and Belts**
* **Hoses:** Briefly inspect radiator and heater hoses for cracks, bulges, or leaks. They should feel firm, not overly soft or squishy.
* **Belts:** Check serpentine belts for cracks, fraying, or excessive looseness.

---

## 8. **Tire Pressure**
* **Importance:** Incorrect tire pressure affects safety, fuel efficiency, and tire lifespan.
* **Procedure:** Use a tire pressure gauge to check each tire (including the spare). Refer to your car's manual or the sticker inside the driver's door for the recommended pressure.
  * 
---

## 9. **Lights Check**
* **Exterior:** Turn on headlights (high and low beam), turn signals, brake lights (get someone to help you check these), and hazard lights.
* **Interior:** Check dashboard warning lights. If any are on (especially 'Check Engine', 'Oil Pressure', 'Battery', or 'Brake'), investigate further.

---

## 10. **Listen to Your Engine**
* **Sounds:** Pay attention to any unusual noises like knocking, squealing, hissing, or grinding. These can indicate underlying problems.

---

*Regular basic checks can help prevent larger issues down the road.*
''';


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Guides',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        backgroundColor: const Color.fromARGB(233, 214, 251, 250),
        centerTitle: true,
        elevation: 1,
      ),
      drawer: const app_nav.NavigationDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Access basic troubleshooting information for various vehicles, even without internet. View guides directly in the app.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.blueGrey),
            ),
          ),
          const SizedBox(height: 20),

          // New Video Guide Card, now with both video and markdown content
          _buildGuideCard(
            context,
            title: 'Basic Engine Check', // Title can be more general now
            description: 'A visual and text guide on performing a basic engine check.',
            icon: Icons.play_circle_fill,
            videoAssetPath: 'assets/videos/basicenginescheck.mp4', // Your video asset path
            markdownContent: _basicEngineCheckContent, // Now providing markdown content
          ),
          const SizedBox(height: 10), // Spacing between cards

          // Existing Markdown Guide Cards
          _buildGuideCard(
            context,
            title: 'Engine Starting Issues',
            description: 'Troubleshoot common reasons why your vehicle\'s engine might not start.',
            icon: Icons.power_settings_new,
            videoAssetPath: 'assets/videos/',
            markdownContent: _engineStartingGuideContent,
            
          ),
          _buildGuideCard(
            context,
            title: 'Flat Tire Changing Guide',
            description: 'Step-by-step instructions on how to safely change a flat tire on your vehicle.',
            markdownContent: _flatTireGuideContent,
            icon: Icons.tire_repair,
            videoAssetPath: 'assets/videos/',
          ),
          _buildGuideCard(
            context,
            title: 'Battery Problems Diagnosis',
            description: 'Learn how to identify and address common battery-related problems in your vehicle.',
            markdownContent: _batteryDiagnosisGuideContent,
            icon: Icons.battery_charging_full,
            videoAssetPath: 'assets/videos/',
          ),
          _buildGuideCard(
            context,
            title: 'Brake System Inspection',
            description: 'A guide to inspecting your vehicle\'s brake system for common issues.',
            markdownContent: _brakeInspectionGuideContent,
            icon: Icons.car_crash,
            videoAssetPath: 'assets/videos/',
          ),
          _buildGuideCard(
            context,
            title: 'Oil Change Procedure',
            description: 'Step-by-step guide on how to perform a basic oil change for your vehicle.',
            markdownContent: _oilChangeGuideContent,
            icon: Icons.oil_barrel,
            videoAssetPath: 'assets/videos/',
          ),
          _buildGuideCard(
            context,
            title: 'Overheating Engine Troubleshooting',
            description: 'Diagnose and address common causes of an overheating engine in your vehicle.',
            markdownContent: _overheatingEngineGuideContent,
            icon: Icons.thermostat,
            videoAssetPath: 'assets/videos/',
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard(BuildContext context, {
    required String title,
    required String description,
    String? markdownContent,
    String? videoAssetPath, // New: Optional video asset path
    required IconData icon,
  }) {
    // Determine which buttons to show
    final bool hasMarkdownContent = markdownContent != null && markdownContent.isNotEmpty;
    final bool hasVideoContent = videoAssetPath != null && videoAssetPath.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 30, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Row( // Use a Row to hold multiple buttons
                mainAxisSize: MainAxisSize.min, // Keep row compact
                children: [
                  if (hasVideoContent)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0), // Spacing between buttons
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GuideViewerScreen(
                                guideTitle: title,
                                videoAssetPath: videoAssetPath,
                                // Pass markdownContent as null if primarily a video guide
                                markdownContent: null, // Ensure only video is passed for video view
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.videocam, color: Colors.white),
                        label: const Text('Watch Video', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                      ),
                    ),
                  if (hasMarkdownContent)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GuideViewerScreen(
                              guideTitle: title,
                              markdownContent: markdownContent,
                              // Pass videoAssetPath as null if primarily a text guide
                              videoAssetPath: null, // Ensure only markdown is passed for text view
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.remove_red_eye, color: Colors.white),
                      label: const Text('View Guide', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 2,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
