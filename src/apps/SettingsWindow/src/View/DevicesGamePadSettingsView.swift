import SwiftUI

struct DevicesGamePadSettingsView: View {
  let connectedDevice: LibKrbn.ConnectedDevice
  @Binding var showing: Bool
  @ObservedObject private var settings = LibKrbn.Settings.shared
  @State var connectedDeviceSetting: LibKrbn.ConnectedDeviceSetting?

  var body: some View {
    ZStack(alignment: .topLeading) {
      VStack(alignment: .leading, spacing: 12.0) {
        if let s = connectedDeviceSetting {
          let binding = Binding {
            s
          } set: {
            connectedDeviceSetting = $0
          }
          Text("\(connectedDevice.productName) (\(connectedDevice.manufacturerName))")
            .padding(.leading, 40)
            .padding(.top, 20)

          TabView {
            XYStickTabView(connectedDeviceSetting: binding)
              .padding()
              .tabItem {
                Text("XY stick")
              }

            WheelsStickTabView(connectedDeviceSetting: binding)
              .padding()
              .tabItem {
                Text("Wheels stick")
              }

            OthersTabView(connectedDeviceSetting: binding)
              .padding()
              .tabItem {
                Text("Others")
              }
          }
        }

        Spacer()
      }

      SheetCloseButton {
        showing = false
      }
    }
    .padding()
    .frame(width: 1000, height: 600)
    .onAppear {
      setConnectedDeviceSetting()
    }
    .onChange(of: settings.connectedDeviceSettings) { _ in
      setConnectedDeviceSetting()
    }
  }

  private func setConnectedDeviceSetting() {
    connectedDeviceSetting = settings.findConnectedDeviceSetting(connectedDevice)
  }

  struct XYStickTabView: View {
    @Binding var connectedDeviceSetting: LibKrbn.ConnectedDeviceSetting

    var body: some View {
      VStack(alignment: .leading) {
        StickParametersView(
          continuedMovementAbsoluteMagnitudeThreshold: $connectedDeviceSetting
            .gamePadXYStickContinuedMovementAbsoluteMagnitudeThreshold,
          continuedMovementAbsoluteMagnitudeThresholdDefaultValue:
            libkrbn_core_configuration_game_pad_xy_stick_continued_movement_absolute_magnitude_threshold_default_value(),

          continuedMovementIntervalMilliseconds: $connectedDeviceSetting
            .gamePadXYStickContinuedMovementIntervalMilliseconds,
          continuedMovementIntervalMillisecondsDefaultValue: Int(
            libkrbn_core_configuration_game_pad_xy_stick_continued_movement_interval_milliseconds_default_value()
          ),

          flickingInputWindowMilliseconds: $connectedDeviceSetting
            .gamePadXYStickFlickingInputWindowMilliseconds,
          flickingInputWindowMillisecondsDefaultValue: Int(
            libkrbn_core_configuration_game_pad_xy_stick_flicking_input_window_milliseconds_default_value()
          )
        )

        HStack(spacing: 20.0) {
          FormulaView(
            name: "X formula",
            value: $connectedDeviceSetting.gamePadStickXFormula
          )

          FormulaView(
            name: "Y formula",
            value: $connectedDeviceSetting.gamePadStickYFormula
          )
        }
        .padding(.top, 20.0)

        Spacer()
      }
    }
  }

  struct WheelsStickTabView: View {
    @Binding var connectedDeviceSetting: LibKrbn.ConnectedDeviceSetting

    var body: some View {
      VStack(alignment: .leading) {
        StickParametersView(
          continuedMovementAbsoluteMagnitudeThreshold: $connectedDeviceSetting
            .gamePadWheelsStickContinuedMovementAbsoluteMagnitudeThreshold,
          continuedMovementAbsoluteMagnitudeThresholdDefaultValue:
            libkrbn_core_configuration_game_pad_wheels_stick_continued_movement_absolute_magnitude_threshold_default_value(),

          continuedMovementIntervalMilliseconds: $connectedDeviceSetting
            .gamePadWheelsStickContinuedMovementIntervalMilliseconds,
          continuedMovementIntervalMillisecondsDefaultValue: Int(
            libkrbn_core_configuration_game_pad_wheels_stick_continued_movement_interval_milliseconds_default_value()
          ),

          flickingInputWindowMilliseconds: $connectedDeviceSetting
            .gamePadWheelsStickFlickingInputWindowMilliseconds,
          flickingInputWindowMillisecondsDefaultValue: Int(
            libkrbn_core_configuration_game_pad_wheels_stick_flicking_input_window_milliseconds_default_value()
          )
        )

        HStack(spacing: 20.0) {
          FormulaView(
            name: "vertical wheel formula",
            value: $connectedDeviceSetting.gamePadStickVerticalWheelFormula
          )

          FormulaView(
            name: "horizontal wheel formula",
            value: $connectedDeviceSetting.gamePadStickHorizontalWheelFormula
          )
        }
        .padding(.top, 20.0)

        Spacer()
      }
    }
  }

  struct OthersTabView: View {
    @Binding var connectedDeviceSetting: LibKrbn.ConnectedDeviceSetting

    var body: some View {
      VStack(alignment: .leading) {
        HStack {
          Toggle(isOn: $connectedDeviceSetting.gamePadSwapSticks) {
            Text("Swap gamepad XY and wheels sticks")
          }
          .switchToggleStyle(controlSize: .mini, font: .callout)

          Spacer()
        }

        Spacer()
      }
    }
  }

  struct StickParametersView: View {
    @Binding var continuedMovementAbsoluteMagnitudeThreshold: Double
    let continuedMovementAbsoluteMagnitudeThresholdDefaultValue: Double

    @Binding var continuedMovementIntervalMilliseconds: Int
    let continuedMovementIntervalMillisecondsDefaultValue: Int

    @Binding var flickingInputWindowMilliseconds: Int
    let flickingInputWindowMillisecondsDefaultValue: Int

    var body: some View {
      Grid(alignment: .leadingFirstTextBaseline) {
        GridRow {
          Text("Continued movement absolute magnitude threshold:")
            .gridColumnAlignment(.trailing)

          DoubleTextField(
            value: $continuedMovementAbsoluteMagnitudeThreshold,
            range: 0...1,
            step: 0.1,
            maximumFractionDigits: 2,
            width: 60)

          Text(
            "(Default: \(String(format: "%.2f", continuedMovementAbsoluteMagnitudeThresholdDefaultValue)))"
          )
        }

        GridRow {
          Text("Continued movement interval milliseconds:")

          IntTextField(
            value: $continuedMovementIntervalMilliseconds,
            range: 0...1000,
            step: 1,
            width: 60)

          Text("(Default: \(continuedMovementIntervalMillisecondsDefaultValue))")
        }

        GridRow {
          Text("Flicking input window milliseconds:")

          IntTextField(
            value: $flickingInputWindowMilliseconds,
            range: 0...1000,
            step: 1,
            width: 60)

          Text("(Default: \(flickingInputWindowMillisecondsDefaultValue))")
        }
      }
    }
  }

  struct FormulaView: View {
    let name: String
    @Binding var value: String
    @State private var error = false

    var body: some View {
      VStack {
        HStack {
          Text(name)

          if error {
            Text("Invalid formula")
              .foregroundColor(Color.errorForeground)
              .background(Color.errorBackground)
          }

          Spacer()
        }

        TextEditor(text: $value)
          .frame(height: 250.0)
      }
      .onChange(of: value) { newValue in
        update(newValue)
      }
    }

    private func update(_ newValue: String) {
      if libkrbn_core_configuration_game_pad_validate_stick_formula(newValue.cString(using: .utf8))
      {
        error = false
      } else {
        error = true
      }
    }
  }
}

struct DevicesGamePadSettingsView_Previews: PreviewProvider {
  @State static var connectedDevice = LibKrbn.ConnectedDevice(
    index: 0,
    manufacturerName: "",
    productName: "",
    transport: "",
    vendorId: 0,
    productId: 0,
    deviceAddress: "",
    isKeyboard: false,
    isPointingDevice: false,
    isGamePad: true,
    isBuiltInKeyboard: false,
    isBuiltInTrackpad: false,
    isBuiltInTouchBar: false,
    isAppleDevice: false,
    isKarabinerVirtualHidDevice: false
  )
  @State static var showing = true

  static var previews: some View {
    DevicesGamePadSettingsView(
      connectedDevice: connectedDevice,
      showing: $showing)
  }
}
