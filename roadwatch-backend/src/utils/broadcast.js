let ioInstance = null;

function setIo(io) {
  ioInstance = io;
}

function emit(event, payload) {
  try {
    if (ioInstance) ioInstance.emit(event, payload);
  } catch (e) {
    // swallow errors to avoid crashing controllers
    // logging is done elsewhere
  }
}

module.exports = { setIo, emit };
