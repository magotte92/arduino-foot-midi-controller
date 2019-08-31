#include <Bounce2.h>
#include <MIDI.h>

MIDI_CREATE_DEFAULT_INSTANCE();

// I'm creating a struct to avoid repeating my code
typedef struct {
  const int btn_pin; // button pin number
  const int corr_led; // the button's corresponding LED pin number
  const int md_key; // Which midi key to change
  int ledState; // LED state
  Bounce bc; // attach a debouncer
} btn;

// Button Setup

#define btn_count 10 // you can add as many buttons as you want as long as arduino inputs' allows it
btn btns[10] = {
  {22, 13, 80, LOW, Bounce()},
  {23, 33, 81, LOW, Bounce()},
  {24, 34, 82, LOW, Bounce()},
  {25, 35, 83, LOW, Bounce()},
  {26, 36, 84, LOW, Bounce()},
  {27, 37, 85, LOW, Bounce()},
  {28, 38, 86, LOW, Bounce()},
  {29, 39, 87, LOW, Bounce()},
  {30, 40, 88, LOW, Bounce()},
  {31, 41, 89, LOW, Bounce()}
};

void setup() {
  
  
  for (int i = 0; i < btn_count; i++) {
    btns[i].bc.attach(btns[i].btn_pin , INPUT_PULLUP); // Attach the debouncer
    btns[i].bc.interval(25); // Use a debounce interval of 25 milliseconds
    pinMode(btns[i].corr_led, OUTPUT); // LED setup
    digitalWrite(btns[i].corr_led, btns[i].ledState);
  }

  // Start MIDI transmition
  MIDI.begin(MIDI_CHANNEL_OFF); //start midi

}

void loop() {
  for (int i = 0; i < btn_count; i++) {
    Button(i);
  }

}

void Button(int what) {
  // Update the Bounce instance
  btns[what].bc.update();
  if ( btns[what].bc.fell() ) {
    btns[what].ledState = !btns[what].ledState; // Toggle LED state
    digitalWrite(btns[what].corr_led, btns[what].ledState); // Apply new LED state
    MIDI.sendControlChange(btns[what].md_key, 127, 1); // Send the corresponding key change to MIDI.
  }
  delay(5);

}
