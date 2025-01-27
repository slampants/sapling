/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#pragma once

#include "eden/fs/store/IObjectStore.h"

namespace facebook::eden {

class LoggingFetchContext : public ObjectFetchContext {
 public:
  struct Request {
    Request(ObjectType t, ObjectId h, Origin o) : type{t}, hash{h}, origin{o} {}

    ObjectType type;
    ObjectId hash;
    Origin origin;
  };

  void didFetch(ObjectType type, const ObjectId& hash, Origin origin) override {
    requests.emplace_back(type, hash, origin);
  }

  std::optional<pid_t> getClientPid() const override {
    return std::nullopt;
  }

  Cause getCause() const override {
    return Cause::Unknown;
  }

  const std::unordered_map<std::string, std::string>* FOLLY_NULLABLE
  getRequestInfo() const override {
    return nullptr;
  }

  std::vector<Request> requests;
};

} // namespace facebook::eden
