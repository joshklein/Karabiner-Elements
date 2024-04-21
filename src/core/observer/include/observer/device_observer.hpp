#pragma once

// `krbn::observer::device_observer` can be used safely in a multi-threaded environment.

#include "components_manager_killer.hpp"
#include "event_queue.hpp"
#include "grabber_client.hpp"
#include "hid_queue_values_converter.hpp"
#include "iokit_utility.hpp"
#include "logger.hpp"
#include "types.hpp"
#include <pqrs/dispatcher.hpp>
#include <pqrs/osx/iokit_hid_manager.hpp>
#include <pqrs/osx/iokit_hid_queue_value_monitor.hpp>
#include <pqrs/osx/iokit_types.hpp>

namespace krbn {
namespace observer {
class device_observer final : public pqrs::dispatcher::extra::dispatcher_client {
public:
  device_observer(const device_observer&) = delete;

  device_observer(std::weak_ptr<grabber_client> grabber_client) : dispatcher_client(),
                                                                  grabber_client_(grabber_client) {
    // hid_manager_

    std::vector<pqrs::cf::cf_ptr<CFDictionaryRef>> matching_dictionaries{
        pqrs::osx::iokit_hid_manager::make_matching_dictionary(
            pqrs::hid::usage_page::generic_desktop,
            pqrs::hid::usage::generic_desktop::keyboard),

        pqrs::osx::iokit_hid_manager::make_matching_dictionary(
            pqrs::hid::usage_page::generic_desktop,
            pqrs::hid::usage::generic_desktop::mouse),

        pqrs::osx::iokit_hid_manager::make_matching_dictionary(
            pqrs::hid::usage_page::generic_desktop,
            pqrs::hid::usage::generic_desktop::pointer),

        pqrs::osx::iokit_hid_manager::make_matching_dictionary(
            pqrs::hid::usage_page::generic_desktop,
            pqrs::hid::usage::generic_desktop::joystick),

        pqrs::osx::iokit_hid_manager::make_matching_dictionary(
            pqrs::hid::usage_page::generic_desktop,
            pqrs::hid::usage::generic_desktop::game_pad),
    };

    hid_manager_ = std::make_unique<pqrs::osx::iokit_hid_manager>(weak_dispatcher_,
                                                                  pqrs::cf::run_loop_thread::extra::get_shared_run_loop_thread(),
                                                                  matching_dictionaries,
                                                                  std::chrono::milliseconds(0));

    hid_manager_->device_matched.connect([this](auto&& registry_entry_id, auto&& device_ptr) {
      if (device_ptr) {
        if (iokit_utility::is_karabiner_virtual_hid_device(*device_ptr)) {
          return;
        }

        iokit_utility::log_matching_device(registry_entry_id, *device_ptr);

        auto device_id = make_device_id(registry_entry_id);
        auto device_name = iokit_utility::make_device_name_for_log(device_id,
                                                                   *device_ptr);
        auto device_properties = krbn::device_properties(device_id,
                                                         *device_ptr);

        auto hid_queue_value_monitor = std::make_shared<pqrs::osx::iokit_hid_queue_value_monitor>(weak_dispatcher_,
                                                                                                  pqrs::cf::run_loop_thread::extra::get_shared_run_loop_thread(),
                                                                                                  *device_ptr);
        hid_queue_value_monitors_[device_id] = hid_queue_value_monitor;

        hid_queue_value_monitor->values_arrived.connect([this, device_id, device_properties](auto&& values_ptr) {
          auto event_queue = event_queue::utility::make_queue(device_properties,
                                                              hid_queue_values_converter_.make_hid_values(device_id,
                                                                                                          values_ptr),
                                                              event_origin::observed_device);
          for (const auto& entry : event_queue->get_entries()) {
            if (auto e = entry.get_event().template get_if<momentary_switch_event>()) {
              if (auto client = grabber_client_.lock()) {
                client->async_momentary_switch_event_arrived(device_id,
                                                             *e,
                                                             entry.get_event_type(),
                                                             entry.get_event_time_stamp().get_time_stamp());
              }
            }
          }
        });

        hid_queue_value_monitor->started.connect([this, device_id, device_name] {
          logger::get_logger()->info("{0} is observed.", device_name);

          observed_devices_.insert(device_id);
        });

        hid_queue_value_monitor->error_occurred.connect([](auto&& message, auto&& kr) {
          if (kr.not_permitted()) {
            logger::get_logger()->warn("hid_queue_value_monitor not_permitted error");
            if (auto killer = components_manager_killer::get_shared_components_manager_killer()) {
              killer->async_kill();
            }
          }
        });

        hid_queue_value_monitor->async_start(kIOHIDOptionsTypeNone,
                                             std::chrono::milliseconds(3000));
      }

      async_rescan();
    });

    hid_manager_->device_terminated.connect([this](auto&& registry_entry_id) {
      auto device_id = make_device_id(registry_entry_id);

      logger::get_logger()->info("device_id:{0} is terminated.", type_safe::get(device_id));

      hid_queue_value_monitors_.erase(device_id);
      hid_queue_values_converter_.erase_device(device_id);
      observed_devices_.erase(device_id);

      hat_switch_converter::get_global_hat_switch_converter()->erase_device(device_id);

      async_rescan();
    });

    hid_manager_->error_occurred.connect([](auto&& message, auto&& kern_return) {
      logger::get_logger()->error("{0}: {1}", message, kern_return.to_string());
    });
  }

  virtual ~device_observer(void) {
    detach_from_dispatcher([this] {
      hid_manager_ = nullptr;
      hid_queue_value_monitors_.clear();

      hat_switch_converter::get_global_hat_switch_converter()->clear();
    });

    logger::get_logger()->info("device_observer is stopped.");
  }

  void async_start(void) const {
    enqueue_to_dispatcher([this] {
      hid_manager_->async_start();

      logger::get_logger()->info("device_observer is started.");
    });
  }

  void async_rescan(void) const {
    enqueue_to_dispatcher([this] {
      hid_manager_->async_rescan();

      logger::get_logger()->info("rescan devices...");
    });
  }

private:
  std::weak_ptr<grabber_client> grabber_client_;

  std::unique_ptr<pqrs::osx::iokit_hid_manager> hid_manager_;
  std::unordered_map<device_id, std::shared_ptr<pqrs::osx::iokit_hid_queue_value_monitor>> hid_queue_value_monitors_;
  hid_queue_values_converter hid_queue_values_converter_;
  std::unordered_set<device_id> observed_devices_;
};
} // namespace observer
} // namespace krbn
