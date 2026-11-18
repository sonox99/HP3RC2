// SPDX-License-Identifier: GPL-3.0+
// HP3 VU1 trace helper. Compile-time opt-in: -DHP3_VU1_TRACE=1
#pragma once

#ifndef HP3_VU1_TRACE
#define HP3_VU1_TRACE 0
#endif

#if HP3_VU1_TRACE

#include <array>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <functional>
#include <string>
#include <thread>

namespace HP3VU1Trace
{
struct CaptureContext
{
	u32 id = 0;
	u32 asset_ref_id = 0;
	u32 batch_id = 0;
};

inline thread_local CaptureContext s_context{};

class ScopedCaptureContext
{
public:
	explicit ScopedCaptureContext(u32 id, u32 asset_ref_id = 0, u32 batch_id = 0)
		: m_previous(s_context)
	{
		s_context = {id, asset_ref_id, batch_id};
	}

	~ScopedCaptureContext() { s_context = m_previous; }

	ScopedCaptureContext(const ScopedCaptureContext&) = delete;
	ScopedCaptureContext& operator=(const ScopedCaptureContext&) = delete;

private:
	CaptureContext m_previous;
};

class ThreadWriter
{
public:
	~ThreadWriter() { Flush(); if (m_file) std::fclose(m_file); }

	void Write(const char* line, size_t length)
	{
		if (!Open())
			return;

		if (length > m_buffer.size())
		{
			Flush();
			std::fwrite(line, 1, length, m_file);
			return;
		}

		if (m_used + length > m_buffer.size())
			Flush();

		std::memcpy(m_buffer.data() + m_used, line, length);
		m_used += length;
		if (m_used >= (m_buffer.size() * 3 / 4))
			Flush();
	}

private:
	bool Open()
	{
		if (m_file)
			return true;

		const char* configured_dir = std::getenv("HP3_VU1_TRACE_DIR");
		const std::filesystem::path directory = configured_dir && configured_dir[0] ? configured_dir : "captures/vu1-trace";
		std::error_code error;
		std::filesystem::create_directories(directory, error);
		if (error)
			return false;

		const size_t thread_id = std::hash<std::thread::id>{}(std::this_thread::get_id());
		const std::filesystem::path path = directory / ("vu1-trace-" + std::to_string(thread_id) + ".csv");
		m_file = std::fopen(path.string().c_str(), "ab");
		return m_file != nullptr;
	}

	void Flush()
	{
		if (m_file && m_used)
		{
			std::fwrite(m_buffer.data(), 1, m_used, m_file);
			std::fflush(m_file);
			m_used = 0;
		}
	}

	std::FILE* m_file = nullptr;
	std::array<char, 65536> m_buffer{};
	size_t m_used = 0;
};

inline thread_local ThreadWriter s_writer{};

inline void RecordInterpreter(u32 pc, u32 lower, u32 upper, u64 cycle)
{
	if (!s_context.id)
		return;

	char line[192];
	const int length = std::snprintf(line, sizeof(line),
		"interp,%u,%u,%u,%08X,%08X,%08X,%llu\n",
		s_context.id, s_context.asset_ref_id, s_context.batch_id, pc, lower, upper,
		static_cast<unsigned long long>(cycle));
	if (length > 0 && static_cast<size_t>(length) < sizeof(line))
		s_writer.Write(line, static_cast<size_t>(length));
}

inline void RecordMicroVUDispatch(u32 start_pc, u32 cycles, u64 elapsed_ns)
{
	if (!s_context.id)
		return;

	char line[192];
	const int length = std::snprintf(line, sizeof(line),
		"microVU,%u,%u,%u,%08X,%u,%llu\n",
		s_context.id, s_context.asset_ref_id, s_context.batch_id, start_pc, cycles,
		static_cast<unsigned long long>(elapsed_ns));
	if (length > 0 && static_cast<size_t>(length) < sizeof(line))
		s_writer.Write(line, static_cast<size_t>(length));
}
} // namespace HP3VU1Trace

#else

namespace HP3VU1Trace
{
class ScopedCaptureContext
{
public:
	ScopedCaptureContext(u32, u32 = 0, u32 = 0) {}
};
inline void RecordInterpreter(u32, u32, u32, u64) {}
inline void RecordMicroVUDispatch(u32, u32, u64) {}
} // namespace HP3VU1Trace

#endif
