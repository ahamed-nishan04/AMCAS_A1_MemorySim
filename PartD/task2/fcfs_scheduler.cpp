#include <vector>

#include "base/base.h"
#include "dram_controller/controller.h"
#include "dram_controller/scheduler.h"

namespace Ramulator {

// Strict first-come-first-served DRAM scheduler.
//
// Ramulator 2.0a ships only FRFCFS (generic_scheduler.cpp), whose compare()
// promotes any request whose next command is already legal -- that is the
// "first-ready" half of FR-FCFS, and it is what turns an open row into a
// stream of column accesses.
//
// This scheduler drops that half: the oldest request in the buffer always
// wins, ready or not. The controller (generic_dram_controller.cpp:346) then
// checks check_ready() on whatever it is handed and issues nothing if the
// command is illegal, so a request at the head that needs a PRE+ACT stalls
// the channel until its row is open -- even when a younger request behind it
// could have issued a column command to an already-open row immediately.
class FCFS : public IScheduler, public Implementation {
  RAMULATOR_REGISTER_IMPLEMENTATION(IScheduler, FCFS, "FCFS", "Strict FCFS DRAM Scheduler.")
  private:
    IDRAM* m_dram;

  public:
    void init() override { };

    void setup(IFrontEnd* frontend, IMemorySystem* memory_system) override {
      m_dram = cast_parent<IDRAMController>()->m_dram;
    };

    ReqBuffer::iterator compare(ReqBuffer::iterator req1, ReqBuffer::iterator req2) override {
      // Arrival order only. No readiness check.
      if (req1->arrive <= req2->arrive) {
        return req1;
      } else {
        return req2;
      }
    }

    ReqBuffer::iterator get_best_request(ReqBuffer& buffer) override {
      if (buffer.size() == 0) {
        return buffer.end();
      }

      for (auto& req : buffer) {
        req.command = m_dram->get_preq_command(req.final_command, req.addr_vec);
      }

      auto candidate = buffer.begin();
      for (auto next = std::next(buffer.begin(), 1); next != buffer.end(); next++) {
        candidate = compare(candidate, next);
      }
      return candidate;
    }
};

}       // namespace Ramulator
